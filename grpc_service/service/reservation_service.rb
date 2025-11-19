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

          # -----------------------------------------------------------
          # 공통: HH:MM → hour, min 변환
          # -----------------------------------------------------------
          def parse_hhmm(str)
            str.split(":").map(&:to_i)
          end

          # -----------------------------------------------------------
          # 공통: 운영시간 범위 내인지 확인 (HH:MM 기반)
          # -----------------------------------------------------------
          def within_operating_hours?(start_time, end_time, op)
            # HH:MM → 숫자
            op_start_hour, op_start_min = parse_hhmm(op.opening_time)
            op_end_hour,   op_end_min   = parse_hhmm(op.closing_time)

            st_h, st_m = start_time.hour, start_time.min
            et_h, et_m = end_time.hour,   end_time.min

            start_ok = (st_h > op_start_hour) || (st_h == op_start_hour && st_m >= op_start_min)
            end_ok   = (et_h < op_end_hour)   || (et_h == op_end_hour && et_m <= op_end_min)

            start_ok && end_ok
          end

          # -----------------------------------------------------------
          # 공통: 예외시간 충돌 확인 (HH:MM 기반)
          # -----------------------------------------------------------
          def conflict_with_exception?(start_time, end_time, ex)
            st_h, st_m = start_time.hour, start_time.min
            et_h, et_m = end_time.hour,   end_time.min

            ex_start_hour, ex_start_min = parse_hhmm(ex.opening_time)
            ex_end_hour,   ex_end_min   = parse_hhmm(ex.closing_time)

            start_before_ex_end = (st_h < ex_end_hour) || (st_h == ex_end_hour && st_m < ex_end_min)
            end_after_ex_start  = (et_h > ex_start_hour) || (et_h == ex_start_hour && et_m > ex_start_min)

            start_before_ex_end && end_after_ex_start
          end

          # ===========================================================
          # 1. 예약 생성
          # ===========================================================
          def create_reservation(request, _call)
            puts "[DEBUG] create_reservation called by #{Current.user_code} (role: #{Current.user_role})"
            authorize!("student")

            start_time = request.start_time&.seconds ? Time.at(request.start_time.seconds) : nil
            end_time   = request.end_time&.seconds ? Time.at(request.end_time.seconds) : nil

            raise_invalid("start_time is required") unless start_time
            raise_invalid("end_time is required") unless end_time
            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # 1) 운영시간 조회 (요일 기반)
            op = ::RoomOperatingHour.where(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            ).first
            raise_precondition("No operating hour defined for this day") unless op

            # 운영시간 체크
            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Reservation time is outside operating hours")
            end

            # 2) 예외시간 조회 (날짜 기반)
            exception = ::RoomException.where(
              room_id: room.id,
              holiday_date: start_time.to_date,
              deleted_at: nil
            ).first

            if exception
              # 종일 휴무
              if exception.opening_time.nil? && exception.closing_time.nil?
                raise_precondition("Reservation not allowed: holiday (full-day closed)")
              end

              # 부분 휴무
              if exception.opening_time.present? && exception.closing_time.present?
                if conflict_with_exception?(start_time, end_time, exception)
                  raise_precondition("Reservation conflicts with room exception period")
                end
              end
            end

            # 3) 예약 중복 체크
            overlap = ::Reservation.where(room_id: room.id, deleted_at: nil)
                                   .where("start_time < ? AND end_time > ?", end_time, start_time)
                                   .exists?
            raise_precondition("Reservation time overlaps with an existing reservation") if overlap

            # 생성
            reservation = ::Reservation.new(
              room_id: request.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: start_time,
              end_time: end_time,
              purpose: request.purpose,
              priority: request.priority,
              created_by: Current.user_code
            )

            reservation.save!

            Bannote::Studyroomservice::Reservation::V1::CreateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # ===========================================================
          # 2. 단일 조회
          # ===========================================================
          def get_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            Bannote::Studyroomservice::Reservation::V1::GetReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            raise_not_found("Reservation")
          end

          # ===========================================================
          # 3. 목록 조회
          # ===========================================================
          def list_reservations(request, _call)
            authorize!("student")

            reservations = ::Reservation.where(deleted_at: nil)
            reservations = reservations.where(room_id: request.room_id) if request.room_id.present?
            reservations = reservations.where("start_time >= ?", Time.at(request.start_time_after.seconds)) if request.start_time_after&.seconds
            reservations = reservations.where("end_time <= ?", Time.at(request.end_time_before.seconds)) if request.end_time_before&.seconds
            reservations = reservations.where(group_id: request.group_id) if request.group_id.present?

            Bannote::Studyroomservice::Reservation::V1::ListReservationsResponse.new(
              reservations: reservations.map { |r| reservation_to_proto(r) }
            )
          end

          # ===========================================================
          # 4. 예약 수정
          # ===========================================================
          def update_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?
            raise_permission("Role #{Current.user_role} cannot modify this reservation") unless can_modify?(Current.user_role)

            start_time = request.start_time ? Time.at(request.start_time.seconds) : reservation.start_time
            end_time   = request.end_time   ? Time.at(request.end_time.seconds)   : reservation.end_time

            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id || reservation.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # 운영시간 체크
            op = ::RoomOperatingHour.where(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            ).first
            raise_precondition("No operating hour defined for this day") unless op

            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Reservation time is outside operating hours")
            end

            # 예외 체크
            exception = ::RoomException.where(
              room_id: room.id,
              holiday_date: start_time.to_date,
              deleted_at: nil
            ).first

            if exception
              if exception.opening_time.nil? && exception.closing_time.nil?
                raise_precondition("Reservation not allowed: holiday (full-day closed)")
              end

              if exception.opening_time.present? && exception.closing_time.present?
                if conflict_with_exception?(start_time, end_time, exception)
                  raise_precondition("Reservation conflicts with room exception period")
                end
              end
            end

            # 중복 체크
            overlap = ::Reservation.where(room_id: room.id, deleted_at: nil)
                                   .where("start_time < ? AND end_time > ?", end_time, start_time)
                                   .where.not(id: reservation.id)
                                   .exists?
            raise_precondition("Reservation time overlaps with an existing reservation") if overlap

            reservation.update!(
              room_id: request.room_id || reservation.room_id,
              group_id: request.group_id,
              link_id: request.link_id,
              start_time: start_time,
              end_time: end_time,
              purpose: request.purpose,
              priority: request.priority
            )

            Bannote::Studyroomservice::Reservation::V1::UpdateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          rescue ActiveRecord::RecordNotFound
            raise_not_found("Reservation")
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # ===========================================================
          # 5. 예약 삭제
          # ===========================================================
          def delete_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?
            raise_permission("Role #{Current.user_role} cannot delete this reservation") unless can_modify?(Current.user_role)

            reservation.update!(deleted_at: Time.now)

            Bannote::Studyroomservice::Reservation::V1::DeleteReservationResponse.new(success: true)
          rescue ActiveRecord::RecordNotFound
            raise_not_found("Reservation")
          end

          # ===========================================================
          # 공통
          # ===========================================================
          private

          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise_permission("Requires #{required_role.capitalize} authority or higher.")
            end
          end

          def can_modify?(role)
            ROLE_PRIORITY[role.to_s].to_i >= ROLE_PRIORITY["assistant"]
          end

          def raise_not_found(name)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "#{name} not found")
          end

          def raise_invalid(message)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, message)
          end

          def raise_precondition(message)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, message)
          end

          def raise_permission(message)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, message)
          end

          def reservation_to_proto(reservation)
            Bannote::Studyroomservice::Reservation::V1::Reservation.new(
              id: reservation.id,
              code: reservation.code,
              room_id: reservation.room_id,
              group_id: reservation.group_id,
              link_id: reservation.link_id,
              start_time: Google::Protobuf::Timestamp.new(seconds: reservation.start_time.to_i),
              end_time: Google::Protobuf::Timestamp.new(seconds: reservation.end_time.to_i),
              purpose: reservation.purpose,
              priority: reservation.priority,
              created_at: Google::Protobuf::Timestamp.new(seconds: reservation.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: reservation.updated_at.to_i),
              deleted_at: reservation.deleted_at ? Google::Protobuf::Timestamp.new(seconds: reservation.deleted_at.to_i) : nil
            )
          end
        end
      end
    end
  end
end
