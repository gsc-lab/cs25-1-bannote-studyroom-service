# frozen_string_literal: true

require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'

require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Roomexception
      module V1
        class RoomExceptionServiceHandler < Bannote::Studyroomservice::Roomexception::V1::RoomExceptionService::Service

          # =========================================
          # 1. 방 예외 생성
          # =========================================
          def create_room_exception(request, _call)
            authorize!("assistant")

            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::NOT_FOUND,
              "Room with ID #{request.room_id} not found."
            ) unless ::Room.exists?(request.room_id)

            # ✅ Timestamp → Ruby Time 변환 (문자열인 경우도 안전하게 처리)
            exception_time = if request.exception_date.respond_to?(:seconds)
                              Time.at(request.exception_date.seconds)
                            else
                              Time.parse(request.exception_date.to_s) rescue nil
                            end

            new_exception = ::RoomException.create!(
              room_id: request.room_id,
              exception_date: exception_time,
              is_closed: request.is_closed,
              reason: request.reason
            )

            Bannote::Studyroomservice::Roomexception::V1::CreateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(new_exception)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          rescue ArgumentError
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::INVALID_ARGUMENT,
              "Invalid date format for exception_date."
            )
          end

          # =========================================
          # 2. 단일 예외 조회
          # =========================================
          def get_room_exception(request, _call)
            authorize!("student")

            exception = ::RoomException.find(request.id)
            Bannote::Studyroomservice::Roomexception::V1::GetRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
          end

          # =========================================
          # 3. 예외 목록 조회
          # =========================================
          def list_room_exceptions(request, _call)
            authorize!("student")

            exceptions = ::RoomException.all
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

            exception = ::RoomException.find(request.id)
            exception.update!(
              room_id: request.room_id,
              exception_date: Time.at(request.exception_date.seconds),
              is_closed: request.is_closed,
              reason: request.reason
            )

            Bannote::Studyroomservice::Roomexception::V1::UpdateRoomExceptionResponse.new(
              room_exception: room_exception_to_proto(exception)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 5. 예외 삭제
          # =========================================
          def delete_room_exception(request, _call)
            authorize!("admin")

            exception = ::RoomException.find(request.id)
            exception.update!(deleted_at: Time.now) # soft delete
            Bannote::Studyroomservice::Roomexception::V1::DeleteRoomExceptionResponse.new(
              success: true,
              message: "Room exception deleted successfully."
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room exception not found")
          end

          # =========================================
          # 공통 메서드
          # =========================================
          private

          def authorize!(min_role)
            unless SimulatedUserRoles.has_authority?(
              Current.user_id,
              SimulatedUserRoles::AUTHORITY_LEVELS[min_role]
            )
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{min_role.capitalize} authority or higher."
              )
            end
          end

          def room_exception_to_proto(exception)
            Bannote::Studyroomservice::Roomexception::V1::RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              exception_date: Google::Protobuf::Timestamp.new(seconds: exception.exception_date.to_i),
              is_closed: exception.is_closed,
              reason: exception.reason,
              created_at: Google::Protobuf::Timestamp.new(seconds: exception.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: exception.updated_at.to_i)
            )
          end
        end
      end
    end
  end
end
