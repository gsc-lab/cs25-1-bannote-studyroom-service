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
          # 공통 함수
          # -----------------------------------------------------------
          def parse_hhmm(str)
            str.split(":").map(&:to_i)
          end

          def within_operating_hours?(start_time, end_time, op)
            op_start_hour, op_start_min = parse_hhmm(op.opening_time)
            op_end_hour,   op_end_min   = parse_hhmm(op.closing_time)

            st_h, st_m = start_time.hour, start_time.min
            et_h, et_m = end_time.hour,   end_time.min

            start_ok = (st_h > op_start_hour) || (st_h == op_start_hour && st_m >= op_start_min)
            end_ok   = (et_h < op_end_hour)   || (et_h == op_end_hour && et_m <= op_end_min)

            start_ok && end_ok
          end

          def conflict_with_exception?(start_time, end_time, ex)
            st_h, st_m = start_time.hour, start_time.min
            et_h, et_m = end_time.hour,   end_time.min

            ex_start_hour, ex_start_min = parse_hhmm(ex.opening_time)
            ex_end_hour,   ex_end_min   = parse_hhmm(ex.closing_time)

            start_before_ex_end = (st_h < ex_end_hour) || (st_h == ex_end_hour && st_m < ex_end_min)
            end_after_ex_start  = (et_h > ex_start_hour) || (et_h == ex_start_hour && et_m > ex_end_min)

            start_before_ex_end && end_after_ex_start
          end

          # -----------------------------------------------------------
          # timestamp → Time(Zoned) 변환 (중복 체크 핵심)
          # -----------------------------------------------------------
          def to_local_time(ts)
            return nil if ts.nil? || ts.seconds.nil?
            Time.at(ts.seconds).in_time_zone("Asia/Seoul")
          end

          # ===========================================================
          # 1. 예약 생성
          # ===========================================================
          def create_reservation(request, _call)
            authorize!("student")

            start_time = to_local_time(request.start_time)
            end_time   = to_local_time(request.end_time)

            raise_invalid("start_time is required") unless start_time
            raise_invalid("end_time is required") unless end_time
            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # 운영시간
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op
            raise_precondition("Reservation time is outside operating hours") unless within_operating_hours?(start_time, end_time, op)

            # 예외시간
            exception = ::RoomException.find_by(
              room_id: room.id,
              holiday_date: start_time.to_date,
              deleted_at: nil
            )
            if exception
              if exception.opening_time.nil? && exception.closing_time.nil?
                raise_precondition("Reservation not allowed: holiday")
              end

              if exception.opening_time && exception.closing_time
                raise_precondition("Reservation conflicts with exception") if conflict_with_exception?(start_time, end_time, exception)
              end
            end

            # user_codes 체크
            user_codes = request.user_codes.to_a
            raise_invalid("user_codes cannot be empty") if user_codes.empty?

            # ---------------------------
            # 🔥 중복 체크 (완전 정상 버전)
            # ---------------------------
            overlap = ::Reservation
                      .where(room_id: room.id)
                      .where("start_time < ? AND end_time > ?", end_time, start_time)
                      .exists?

            raise_precondition("Reservation time overlaps") if overlap

            reservation = ::Reservation.create!(
              room_id: request.room_id,
              start_time: start_time,
              end_time: end_time,
              purpose: request.purpose,
              priority: request.priority,
              status: 1,  # CONFIRMED
              user_codes: user_codes,
              created_by: Current.user_code
            )

            CreateReservationResponse.new(
              reservation: reservation_to_proto(reservation)
            )
          end

          # ===========================================================
          # 2. 단건 조회
          # ===========================================================
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

          # ===========================================================
          # 3. 목록 조회
          # ===========================================================
          def list_reservations(request, _call)
            authorize!("student")

            reservations = ::Reservation.where(deleted_at: nil)
            reservations = reservations.where(room_id: request.room_id) if request.room_id.present?
            reservations = reservations.where("start_time >= ?", to_local_time(request.start_time_after)) if request.start_time_after&.seconds
            reservations = reservations.where("end_time <= ?", to_local_time(request.end_time_before)) if request.end_time_before&.seconds

            ListReservationsResponse.new(
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
            raise_permission("Not allowed") unless can_modify?(Current.user_role)

            start_time = request.start_time ? to_local_time(request.start_time) : reservation.start_time
            end_time   = request.end_time ? to_local_time(request.end_time) : reservation.end_time

            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id || reservation.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # 운영시간
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op
            raise_precondition("Outside operating hours") unless within_operating_hours?(start_time, end_time, op)

            # 중복 체크
            overlap = ::Reservation
                      .where(room_id: room.id)
                      .where("start_time < ? AND end_time > ?", end_time, start_time)
                      .where.not(id: reservation.id)
                      .exists?

            raise_precondition("Reservation time overlaps") if overlap

            # user_codes 업데이트
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
          rescue ActiveRecord::RecordNotFound
            raise_not_found("Reservation")
          end

          # ===========================================================
          # 5. 예약 삭제
          # ===========================================================
          def delete_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?
            raise_permission("Not allowed") unless can_modify?(Current.user_role)

            reservation.update!(deleted_at: Time.now, status: 2) # CANCELED

            DeleteReservationResponse.new(success: true)
          end

          # ===========================================================
          # 공통 변환
          # ===========================================================
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

          # proto 변환
          def reservation_to_proto(res)
            ::Bannote::Studyroomservice::Reservation::V1::Reservation.new(
              id: res.id,
              code: res.code,
              room_id: res.room_id,
              start_time: ts(res.start_time),
              end_time: ts(res.end_time),
              purpose: res.purpose,
              priority: res.priority,
              status: res.status,
              created_at: ts(res.created_at),
              updated_at: ts(res.updated_at),
              deleted_at: res.deleted_at ? ts(res.deleted_at) : nil,
              user_codes: res.user_codes.to_a
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
