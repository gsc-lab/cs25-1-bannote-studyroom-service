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
          # 1. 예외 생성
          # =========================================
          def create_room_exception(request, _call)
            authorize!("assistant")

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot add exception to deleted room") if room.deleted_at.present?

            validate_holiday_date!(request.holiday_date)
            validate_times!(request.opening_time, request.closing_time)
            validate_duplicate_exception!(request.room_id, request.holiday_date)

            start_time = request.opening_time
            end_time   = request.closing_time

            if request.opening_time.present? && request.closing_time.present?
              unless exception_overlaps_operating_hours?(room, request.opening_time, request.closing_time)
                raise_invalid("Exception time does not overlap with operating hours.")
              end
            end

            new_exception = ::RoomException.create!(
              room_id: request.room_id,
              holiday_date: request.holiday_date,
              reason: request.reason,
              opening_time: request.opening_time,
              closing_time: request.closing_time,
              created_by: Current.user_code
            )

            Bannote::Studyroomservice::Roomexception::V1::CreateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(new_exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 2. 단일 조회
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
          # 3. 목록 조회
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
          # 4. 예외 수정
          # =========================================
          def update_room_exception(request, _call)
            authorize!("assistant")

            exception = ::RoomException.find_by(id: request.id)
            raise_not_found("Room exception") unless exception
            raise_precondition("Cannot update deleted exception") if exception.deleted_at.present?

            room = ::Room.find_by(id: exception.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot modify exception of deleted room") if room.deleted_at.present?

            validate_holiday_date!(request.holiday_date) if request.holiday_date.present?
            validate_times!(request.opening_time, request.closing_time) if request.opening_time.present? && request.closing_time.present?

            if request.holiday_date.present?
              validate_duplicate_exception_on_update!(exception, request.holiday_date)
            end

            exception.update!(
              holiday_date: request.holiday_date || exception.holiday_date,
              reason:       request.reason       || exception.reason,
              opening_time: request.opening_time || exception.opening_time,
              closing_time: request.closing_time || exception.closing_time
            )

            Bannote::Studyroomservice::Roomexception::V1::UpdateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 5. 예외 삭제
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
          # 공통 유틸
          # =========================================
          private

          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{required_role.capitalize} authority or higher."
              )
            end
          end

          # 날짜 유효성
          def validate_holiday_date!(date)
            return unless date.present?
            Date.parse(date)
          rescue ArgumentError
            raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          # 시간 유효성
          def validate_times!(opening, closing)
            return unless opening.present? && closing.present?

            begin
              start_time = Time.parse(opening)
              end_time   = Time.parse(closing)
            rescue ArgumentError
              raise_invalid("Invalid time format. Expected HH:MM.")
            end

            raise_invalid("Opening time must be before closing time") if start_time >= end_time
          end

          # 예외 날짜 중복
          def validate_duplicate_exception!(room_id, date)
            return unless date.present?

            duplicate = ::RoomException.where(
              room_id: room_id,
              holiday_date: date,
              deleted_at: nil
            ).exists?

            raise_already_exists("Holiday exception already exists for this date.") if duplicate
          end

          def validate_duplicate_exception_on_update!(exception, date)
            duplicate = ::RoomException.where(
              room_id: exception.room_id,
              holiday_date: date,
              deleted_at: nil
            ).where.not(id: exception.id).exists?

            raise_already_exists("An exception already exists for this date.") if duplicate
          end

          # 운영 시간과 겹치는지 검사 (문자열 기반 처리)
          def exception_overlaps_operating_hours?(room, opening_str, closing_str)
            ops = RoomOperatingHour.where(room_id: room.id)
            return false if ops.empty?

            start_t = Time.parse(opening_str)
            end_t   = Time.parse(closing_str)

            ops.any? do |op|
              op_start = Time.parse(op.opening_time.to_s)
              op_end   = Time.parse(op.closing_time.to_s)

              (start_t < op_end) && (end_t > op_start)
            end
          end

          # proto 변환 (strftime 제거)
          def room_exception_to_proto(exception)
            Bannote::Studyroomservice::Roomexception::V1::RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              holiday_date: exception.holiday_date.to_s,
              reason: exception.reason,
              opening_time: exception.opening_time&.to_s,
              closing_time: exception.closing_time&.to_s,
              created_by: exception.created_by,
              created_at: Google::Protobuf::Timestamp.new(seconds: exception.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: exception.updated_at.to_i)
            )
          end
        end
      end
    end
  end
end
