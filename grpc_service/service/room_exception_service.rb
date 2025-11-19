# frozen_string_literal: true

require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Roomexception
      module V1
        class RoomExceptionServiceHandler < Bannote::Studyroomservice::Roomexception::V1::RoomExceptionService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # =========================================
          # 1) CREATE
          # =========================================
          def create_room_exception(request, _call)
            authorize!("assistant")

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot add exception to a deleted room") if room.deleted_at.present?

            # 날짜 검증
            validate_holiday_date!(request.holiday_date)

            # 시간 검증 (초기값 "" → nil 자동 변환)
            opening  = request.opening_time.presence
            closing  = request.closing_time.presence

            validate_exception_time_format!(opening, closing)

            # 중복 검증
            validate_duplicate_exception!(request.room_id, request.holiday_date)

            exception = ::RoomException.create!(
              room_id:      request.room_id,
              holiday_date: request.holiday_date,
              reason:       request.reason,
              opening_time: opening,   # string or nil
              closing_time: closing,   # string or nil
              created_by:   Current.user_code
            )

            Bannote::Studyroomservice::Roomexception::V1::CreateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 2) GET
          # =========================================
          def get_room_exception(request, _call)
            authorize!("student")

            exception = ::RoomException.find_by(id: request.id)
            raise_not_found("Room exception") unless exception
            raise_not_found("Room exception") if exception.deleted_at.present?

            Bannote::Studyroomservice::Roomexception::V1::GetRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          end

          # =========================================
          # 3) LIST
          # =========================================
          def list_room_exceptions(request, _call)
            authorize!("student")

            exceptions = ::RoomException.where(deleted_at: nil)
            exceptions = exceptions.where(room_id: request.room_id) if request.room_id.present?

            Bannote::Studyroomservice::Roomexception::V1::ListRoomExceptionsResponse.new(
              room_exceptions: exceptions.map { |ex| room_exception_to_proto(ex) }
            )
          end

          # =========================================
          # 4) UPDATE
          # =========================================
          def update_room_exception(request, _call)
            authorize!("assistant")

            exception = ::RoomException.find_by(id: request.id)
            raise_not_found("Room exception") unless exception
            raise_precondition("Cannot update deleted exception") if exception.deleted_at.present?

            room = ::Room.find_by(id: exception.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot modify exception of deleted room") if room.deleted_at.present?

            # 날짜 수정 검증
            if request.holiday_date.present?
              validate_holiday_date!(request.holiday_date)
              validate_duplicate_exception_on_update!(exception, request.holiday_date)
            end

            # 시간 수정 검증
            opening = request.opening_time.presence
            closing = request.closing_time.presence

            if request.opening_time.present? || request.closing_time.present?
              validate_exception_time_format!(opening, closing)
            end

            exception.update!(
              holiday_date: request.holiday_date.presence || exception.holiday_date,
              reason:       request.reason.presence       || exception.reason,
              opening_time: opening.nil? ? exception.opening_time : opening,
              closing_time: closing.nil? ? exception.closing_time : closing
            )

            Bannote::Studyroomservice::Roomexception::V1::UpdateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 5) DELETE
          # =========================================
          def delete_room_exception(request, _call)
            authorize!("admin")

            exception = ::RoomException.find_by(id: request.id)
            raise_not_found("Room exception") unless exception
            raise_precondition("Exception already deleted") if exception.deleted_at.present?

            exception.update!(deleted_at: Time.now)

            Bannote::Studyroomservice::Roomexception::V1::DeleteRoomExceptionResponse.new(
              success: true,
              message: "Room exception deleted successfully."
            )
          end

          # =========================================
          # 🔥 유틸
          # =========================================
          private

          # "YYYY-MM-DD" 검증
          def validate_holiday_date!(date)
            raise_invalid("holiday_date is required") unless date.present?
            Date.parse(date)
          rescue
            raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          # ✔ 핵심: "" → nil 처리 + 종일 휴무 처리 포함
          def validate_exception_time_format!(opening, closing)
            opening = opening.presence
            closing = closing.presence

            # 둘 다 nil이면: 종일 휴무 → 통과
            return if opening.nil? && closing.nil?

            # 둘 중 하나만 nil이면 잘못됨
            if opening.nil? && closing.present?
              raise_invalid("opening_time is required when closing_time is provided")
            end
            if closing.nil? && opening.present?
              raise_invalid("closing_time is required when opening_time is provided")
            end

            # 시간 형식 검증
            begin
              start_t = Time.parse(opening)
              end_t   = Time.parse(closing)
            rescue
              raise_invalid("Invalid time format. Expected HH:MM.")
            end

            raise_invalid("opening_time must be before closing_time") if start_t >= end_t
          end

          # 중복 체크
          def validate_duplicate_exception!(room_id, date)
            exists = ::RoomException.where(room_id: room_id, holiday_date: date, deleted_at: nil).exists?
            raise_already_exists("Holiday exception already exists for this date.") if exists
          end

          def validate_duplicate_exception_on_update!(exception, date)
            exists = ::RoomException.where(room_id: exception.room_id,
                                           holiday_date: date,
                                           deleted_at: nil)
                                    .where.not(id: exception.id)
                                    .exists?
            raise_already_exists("An exception already exists for this date.") if exists
          end

          # proto 변환
          def room_exception_to_proto(exception)
            Bannote::Studyroomservice::Roomexception::V1::RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              holiday_date: exception.holiday_date.to_s,
              reason: exception.reason,
              opening_time: exception.opening_time,
              closing_time: exception.closing_time,
              created_by: exception.created_by,
              created_at: Google::Protobuf::Timestamp.new(seconds: exception.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: exception.updated_at.to_i)
            )
          end

          # 에러 및 권한
          def raise_not_found(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, msg); end
          def raise_invalid(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, msg); end
          def raise_precondition(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, msg); end
          def raise_already_exists(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::ALREADY_EXISTS, msg); end

          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied")
            end
          end

        end
      end
    end
  end
end
