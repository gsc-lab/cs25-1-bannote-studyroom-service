# frozen_string_literal: true

require 'reservation/reservation_pb'
require 'reservation/service_pb'
require 'reservation/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Reservation
      module V1
        class ReservationServiceHandler < Bannote::Studyroomservice::Reservation::V1::ReservationService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # =====================================================================
          # 怨듯넻 ?⑥닔
          # =====================================================================

          # ???섏젙?? ??꾩〈 ?녿뒗 臾몄옄?댁쓣 KST濡?媛뺤젣 ?댁꽍
          def parse_datetime(str)
            return nil if str.blank?

            # "2025-11-25T10:30" 泥섎읆 TZ ?녿뒗 媛???KST濡?媛뺤젣 蹂??
            if str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/
              return Time.zone.strptime(str, "%Y-%m-%dT%H:%M")
            end

            # 湲곗〈 ISO8601(+09:00, Z ?ы븿) ?낅젰? 洹몃?濡?Rails parse
            Time.zone.parse(str)
          end

          def combine_date_time(date, hhmm)
            h, m = hhmm.split(":").map(&:to_i)
            Time.new(date.year, date.month, date.day, h, m, 0, "+09:00")
          end

          # HH:mm ??minutes (?좉퇋 ?좎?)
          def hhmm_to_minutes(hhmm)
            return Float::INFINITY if hhmm.nil? || hhmm.strip == ""
            h, m = hhmm.split(":").map(&:to_i)
            (h * 60) + m
          end

          # ?댁쁺?쒓컙 泥댄겕 (遺??⑥쐞 鍮꾧탳)
          def within_operating_hours?(start_time, end_time, op)
            start_m = start_time.hour * 60 + start_time.min
            end_m = end_time.hour * 60 + end_time.min

            op_start = hhmm_to_minutes(op.opening_time)
            op_end = hhmm_to_minutes(op.closing_time)

            start_m >= op_start && end_m <= op_end
          end

          # ?덉쇅?쒓컙 泥댄겕 (湲곗〈 ?좎?)
          def conflict_with_exception?(start_time, end_time, ex)
            date = start_time.to_date
            ex_start = combine_date_time(date, ex.opening_time)
            ex_end = combine_date_time(date, ex.closing_time)

            (start_time < ex_end) && (end_time > ex_start)
          end

          # =====================================================================
          # UserService ?곕룞 (MOCK)
          # =====================================================================

          def fetch_users(user_codes)
            return [] if user_codes.blank?

            user_codes.map do |code|
              ::Bannote::Studyroomservice::Reservation::V1::User.new(
                user_code: code,
                name: "MockUser#{code}",
                department: "MockDept"
              )
            end
          end


          # =====================================================================
          # 1. ?덉빟 ?앹꽦
          # =====================================================================
          def create_reservation(request, _call)
            authorize!("student")

            start_time = parse_datetime(request.start_time)
            end_time = parse_datetime(request.end_time)
            raise_invalid("start_time is required") unless start_time
            raise_invalid("end_time is required")   unless end_time
            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # ?댁쁺?쒓컙 議고쉶
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op

            # ?댁쁺?쒓컙 泥댄겕
            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Reservation time is outside operating hours")
            end

            # 理쒕? ?댁쁺?쒓컙 泥댄겕
            max_minutes = hhmm_to_minutes(op.day_maximum_time)
            duration_minutes = ((end_time - start_time) / 60).to_i

            if duration_minutes > max_minutes
              raise_precondition(
                "Reservation exceeds maximum operating time (#{op.day_maximum_time})"
              )
            end

            # ?덉쇅?쒓컙 ?뺤씤
            exception = ::RoomException.find_by(
              room_id: room.id,
              holiday_date: start_time.to_date,
              deleted_at: nil
            )
            if exception
              if exception.opening_time.nil? && exception.closing_time.nil?
                raise_precondition("Reservation not allowed: holiday")
              elsif conflict_with_exception?(start_time, end_time, exception)
                raise_precondition("Reservation conflicts with exception")
              end
            end

            user_codes = request.user_codes.to_a
            raise_invalid("user_codes cannot be empty") if user_codes.empty?

            # 以묐났 泥댄겕
            overlap = ::Reservation
                        .where(room_id: room.id, deleted_at: nil)
                        .where("start_time < ? AND end_time > ?", end_time, start_time)
                        .exists?
            raise_precondition("Reservation time overlaps") if overlap

            reservation = ::Reservation.create!(
              room_id: request.room_id,
              start_time: start_time,
              end_time: end_time,
              purpose: request.purpose,
              priority: request.priority,
              status: 1,
              user_codes: user_codes,
              created_by: Current.user_code
            )

            CreateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          end

          # =====================================================================
          # 2. ?④굔 議고쉶
          # =====================================================================
          def get_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            GetReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            raise_not_found("Reservation")
          end

          # =====================================================================
          # 3. 紐⑸줉 議고쉶
          # =====================================================================
          def list_reservations(request, _call)
            authorize!("student")

            reservations = ::Reservation.where(deleted_at: nil)

            reservations = reservations.where(room_id: request.room_ids.to_a) if request.room_ids.any?

            reservations = reservations.where("start_time <= ?", parse_datetime(request.end_time_before)) if request.end_time_before.present?
            reservations = reservations.where("end_time >= ?", parse_datetime(request.start_time_after)) if request.start_time_after.present?

            ListReservationsResponse.new(
              reservations: reservations.map { |r| reservation_to_proto(r) }
            )
          end

          # =====================================================================
          # 4. ?덉빟 ?섏젙
          # =====================================================================
          def update_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            start_time = request.start_time.present? ? parse_datetime(request.start_time) : reservation.start_time
            end_time = request.end_time.present?   ? parse_datetime(request.end_time)   : reservation.end_time

            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id || reservation.room_id)
            raise_not_found("Room") unless room

            # ?댁쁺?쒓컙 寃??
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op

            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Outside operating hours")
            end

            # 以묐났 泥댄겕
            overlap = ::Reservation
                        .where(room_id: room.id)
                        .where("start_time < ? AND end_time > ?", end_time, start_time)
                        .where.not(id: reservation.id)
                        .exists?
            raise_precondition("Reservation time overlaps") if overlap

            reservation.user_codes = request.user_codes.to_a if request.user_codes.any?

            reservation.update!(
              room_id: request.room_id || reservation.room_id,
              start_time: start_time,
              end_time: end_time,
              purpose: request.purpose || reservation.purpose,
              priority: request.priority || reservation.priority
            )

            UpdateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          end

          # =====================================================================
          # 5. ?덉빟 ??젣
          # =====================================================================
          def delete_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            reservation.update!(deleted_at: Time.now, status: 2)

            DeleteReservationResponse.new(success: true)
          end

          # =====================================================================
          # 怨듯넻 蹂??
          # =====================================================================
          private

          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise_permission("Requires #{required_role}")
            end
          end

          def can_modify?(role)
            ROLE_PRIORITY[role.to_s] >= ROLE_PRIORITY["assistant"]
          end

          def raise_not_found(msg)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, msg)
          end

          def raise_invalid(msg)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, msg)
          end

          def raise_precondition(msg)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, msg)
          end

          def raise_permission(msg)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, msg)
          end

          # Reservation ??proto 蹂??(users ?ы븿)
          def reservation_to_proto(res)
            users = fetch_users(res.user_codes)

            ::Bannote::Studyroomservice::Reservation::V1::Reservation.new(
              id: res.id,
              code: res.code,
              room_id: res.room_id,
              start_time: res.start_time&.iso8601,
              end_time: res.end_time&.iso8601,
              purpose: res.purpose,
              priority: res.priority,
              status: res.status,
              created_at: ts(res.created_at),
              updated_at: ts(res.updated_at),
              deleted_at: res.deleted_at ? ts(res.deleted_at) : nil,
              user_codes: res.user_codes.to_a,
              users: users
            )
          end

          def ts(time)
            Google::Protobuf::Timestamp.new(seconds: time.to_i)
          end
        end
      end
    end
  end
end
