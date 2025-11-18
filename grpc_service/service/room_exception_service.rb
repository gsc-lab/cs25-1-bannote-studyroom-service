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

          # -------------------------------------------------------
          # ROLE PRIORITY TABLE
          # -------------------------------------------------------
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

            if request.holiday_date.present?
              begin
                Date.parse(request.holiday_date)
              rescue ArgumentError
                raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
              end
            end

            if request.opening_time.present? && request.closing_time.present?
              begin
                start_time = Time.parse(request.opening_time)
                end_time = Time.parse(request.closing_time)
              rescue ArgumentError
                raise_invalid("Invalid time format. Expected HH:MM.")
              end

              raise_invalid("Opening time must be before closing time") if start_time >= end_time
            end

            if request.holiday_date.present?
              duplicate = ::RoomException.where(
                room_id: request.room_id,
                holiday_date: request.holiday_date,
                deleted_at: nil
              ).exists?

              raise_already_exists("Holiday exception already exists for this date.") if duplicate
            end

            if request.opening_time.present? && request.closing_time.present?
              unless exception_overlaps_operating_hours?(room, start_time, end_time, request.holiday_date)
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
          # 2. 단일 예외 조회
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
          # 3. 예외 목록 조회
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

            if request.holiday_date.present?
              begin
                Date.parse(request.holiday_date)
              rescue ArgumentError
                raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
              end
            end

            if request.opening_time.present? && request.closing_time.present?
              begin
                start_time = Time.parse(request.opening_time)
                end_time = Time.parse(request.closing_time)
              rescue ArgumentError
                raise_invalid("Invalid time format. Expected HH:MM.")
              end

              raise_invalid("Opening time must be before closing time") if start_time >= end_time
            end

            if request.holiday_date.present?
              duplicate = ::RoomException.where(
                room_id: exception.room_id,
                holiday_date: request.holiday_date,
                deleted_at: nil
              ).where.not(id: exception.id).exists?

              raise_already_exists("An exception already exists for this date.") if duplicate
            end

            exception.update!(
              room_id: request.room_id,
              holiday_date: request.holiday_date,
              reason: request.reason,
              opening_time: request.opening_time,
              closing_time: request.closing_time
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
          # 공통 Util 메서드
          # =========================================
          private

          # ---- 통일된 role 기반 authorize 로직 ----
          def authorize!(required_role)
            user_role = Current.user_role.to_s

            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{required_role.capitalize} authority or higher."
              )
            end
          end

          def exception_overlaps_operating_hours?(room, start_time, end_time, date)
            ops = RoomOperatingHour.where(room_id: room.id)
            return false if ops.empty?

            ops.any? do |op|
              op_start = Time.parse(op.opening_time.strftime("%H:%M"))
              op_end   = Time.parse(op.closing_time.strftime("%H:%M"))
              (start_time < op_end) && (end_time > op_start)
            end
          end

          def raise_not_found(name)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::NOT_FOUND,
              "#{name} not found"
            )
          end

          def raise_invalid(message)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::INVALID_ARGUMENT,
              message
            )
          end

          def raise_precondition(message)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::FAILED_PRECONDITION,
              message
            )
          end

          def raise_already_exists(message)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::ALREADY_EXISTS,
              message
            )
          end

          def room_exception_to_proto(exception)
            Bannote::Studyroomservice::Roomexception::V1::RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              holiday_date: exception.holiday_date.to_s,
              reason: exception.reason,
              opening_time: exception.opening_time ? exception.opening_time.strftime('%H:%M') : nil,
              closing_time: exception.closing_time ? exception.closing_time.strftime('%H:%M') : nil,
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
