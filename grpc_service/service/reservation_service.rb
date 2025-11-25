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
          # 공통 함수
          # =====================================================================

          # string datetime → Time(KST)
          def parse_datetime(str)
            return nil if str.blank?
            Time.zone.parse(str)
          end

          # 날짜 + HH:mm → Time
          def combine_date_time(date, hhmm)
            h, m = hhmm.split(":").map(&:to_i)
            Time.new(date.year, date.month, date.day, h, m, 0, "+09:00")
          end

          # 운영시간 체크
          def within_operating_hours?(start_time, end_time, op)
            date = start_time.to_date
            op_start = combine_date_time(date, op.opening_time)
            op_end   = combine_date_time(date, op.closing_time)

            start_time >= op_start && end_time <= op_end
          end

          # 예외시간 체크
          def conflict_with_exception?(start_time, end_time, ex)
            date = start_time.to_date
            ex_start = combine_date_time(date, ex.opening_time)
            ex_end   = combine_date_time(date, ex.closing_time)

            (start_time < ex_end) && (end_time > ex_start)
          end

          # =====================================================================
          # UserService 연동 (현재는 MOCK 사용자 데이터)
          # =====================================================================

          def fetch_users(user_codes)
            return [] if user_codes.blank?

            # =======================
            # (1) 실서비스 연동 버전
            # =======================
            # begin
            #   stub = Bannote::Userservice::User::V1::UserService::Stub.new(
            #       "user-service:50051", :this_channel_is_insecure
            #   )
            #   resp = stub.get_users(GetUsersRequest.new(user_codes: user_codes))
            #   return resp.users
            # rescue => e
            #   Rails.logger.error("[UserService] fetch_users failed: #{e.message}")
            #   return []
            # end

            # =======================
            # (2) 현재 mock 데이터 버전
            # =======================
            user_codes.map do |code|
              ::Bannote::Studyroomservice::Reservation::V1::User.new(
                user_code: code,
                name: "MockUser#{code}",
                department: "MockDept"
              )
            end
          end


          # =====================================================================
          # 1. 예약 생성
          # =====================================================================
          def create_reservation(request, _call)
            authorize!("student")

            start_time = parse_datetime(request.start_time)
            end_time   = parse_datetime(request.end_time)
            raise_invalid("start_time is required") unless start_time
            raise_invalid("end_time is required")   unless end_time
            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot reserve a deleted room") if room.deleted_at.present?

            # 운영시간 조회
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op

            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Reservation time is outside operating hours")
            end

            # 최대 운영시간 체크
            if op.day_maximum_time.present?
              max_hours = op.day_maximum_time.to_i
              duration_hours = (end_time - start_time) / 3600.0
              raise_precondition("Reservation exceeds maximum operating time (#{max_hours} hours)") if duration_hours > max_hours
            end

            # 예외시간 확인
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

            # 중복 체크
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
          # 2. 단건 조회
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
          # 3. 목록 조회 (여러 개 room_id + 범위)
          # =====================================================================
          def list_reservations(request, _call)
            authorize!("student")

            reservations = ::Reservation.where(deleted_at: nil)

            # 여러 개 room_ids 처리
            reservations = reservations.where(room_id: request.room_ids.to_a) if request.room_ids.any?

            # 시간 범위
            reservations = reservations.where("start_time >= ?", parse_datetime(request.start_time_after)) if request.start_time_after.present?
            reservations = reservations.where("end_time <= ?", parse_datetime(request.end_time_before))   if request.end_time_before.present?

            ListReservationsResponse.new(
              reservations: reservations.map { |r| reservation_to_proto(r) }
            )
          end

          # =====================================================================
          # 4. 예약 수정
          # =====================================================================
          def update_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            start_time = request.start_time.present? ? parse_datetime(request.start_time) : reservation.start_time
            end_time   = request.end_time.present?   ? parse_datetime(request.end_time)   : reservation.end_time

            raise_invalid("start_time must be earlier than end_time") if start_time >= end_time

            room = ::Room.find_by(id: request.room_id || reservation.room_id)
            raise_not_found("Room") unless room

            # 운영시간 검사
            op = ::RoomOperatingHour.find_by(
              room_id: room.id,
              day_of_week: start_time.wday,
              deleted_at: nil
            )
            raise_precondition("No operating hour defined") unless op

            unless within_operating_hours?(start_time, end_time, op)
              raise_precondition("Outside operating hours")
            end

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
          end

          # =====================================================================
          # 5. 예약 삭제
          # =====================================================================
          def delete_reservation(request, _call)
            authorize!("student")

            reservation = ::Reservation.find_by!(code: request.code)
            raise_not_found("Reservation") if reservation.deleted_at.present?

            reservation.update!(deleted_at: Time.now, status: 2)

            DeleteReservationResponse.new(success: true)
          end

          # =====================================================================
          # 공통 변환
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


          # ------------------------------------------------------------
          # Reservation → proto 변환 (users 포함)
          # ------------------------------------------------------------
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
