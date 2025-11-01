# frozen_string_literal: true

require 'room_operating_hour/room_operating_hour_pb'
require 'room_operating_hour/service_pb'
require 'room_operating_hour/service_services_pb'

require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

module Bannote
  module Studyroomservice
    module Roomoperatinghour
      module V1
        class RoomOperatingHourServiceHandler < Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourService::Service
          
          # =========================================
          # 1. 운영시간 생성
          # =========================================
          def create_room_operating_hour(request, _call)
            authorize!("assistant")

            # 1. gRPC Timestamp → Ruby Time 변환
            begin
              opening_time = Time.at(request.opening_time.seconds)
              closing_time = Time.at(request.closing_time.seconds)
            rescue
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                "Invalid Timestamp format for opening_time or closing_time"
              )
            end

            # 2. 유효성 검증
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::INVALID_ARGUMENT,
              "Opening time must be before closing time."
            ) if opening_time >= closing_time

            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::NOT_FOUND,
              "Room with ID #{request.room_id} not found."
            ) unless ::Room.exists?(request.room_id)

            # 3. DB 저장 (datetime)
            new_operating_hour = ::RoomOperatingHour.create!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: opening_time,
              closing_time: closing_time,
            )

            # 4. 응답 변환
            Bannote::Studyroomservice::Roomoperatinghour::V1::CreateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(new_operating_hour)
            )
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 2. 단일 조회
          # =========================================
          def get_room_operating_hour(request, _call)
            authorize!("student")

            operating_hour = ::RoomOperatingHour.find(request.id)
            Bannote::Studyroomservice::Roomoperatinghour::V1::GetRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room operating hour not found")
          end

          # =========================================
          # 3. 목록 조회
          # =========================================
          def list_room_operating_hours(request, _call)
            authorize!("student")

            operating_hours = ::RoomOperatingHour.all
            operating_hours = operating_hours.where(room_id: request.room_id) if request.room_id.present?

            Bannote::Studyroomservice::Roomoperatinghour::V1::ListRoomOperatingHoursResponse.new(
              room_operating_hours: operating_hours.map { |oh| room_operating_hour_to_proto(oh) }
            )
          end

          # =========================================
          # 4. 수정
          # =========================================
          def update_room_operating_hour(request, _call)
            authorize!("assistant")

            operating_hour = ::RoomOperatingHour.find(request.id)

            # Timestamp → Time 변환
            if request.opening_time&.seconds && request.closing_time&.seconds
              opening_time = Time.at(request.opening_time.seconds)
              closing_time = Time.at(request.closing_time.seconds)

              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::INVALID_ARGUMENT,
                "Opening time must be before closing time."
              ) if opening_time >= closing_time
            end

            operating_hour.update!(
              room_id: request.room_id.presence || operating_hour.room_id,
              day_of_week: request.day_of_week.presence || operating_hour.day_of_week,
              opening_time: opening_time || operating_hour.opening_time,
              closing_time: closing_time || operating_hour.closing_time
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::UpdateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )
          rescue ActiveRecord::RecordNotFound
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, "Room operating hour not found")
          rescue ActiveRecord::RecordInvalid => e
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, e.message)
          end

          # =========================================
          # 5. 삭제 (Soft delete)
          # =========================================
          def delete_room_operating_hour(request, _call)
            authorize!("admin")

            operating_hour = ::RoomOperatingHour.find(request.id)
            operating_hour.update!(deleted_at: Time.current)

            Bannote::Studyroomservice::Roomoperatinghour::V1::DeleteRoomOperatingHourResponse.new(
              success: true,
              message: "Room operating hour deleted successfully"
            )

          rescue ActiveRecord::RecordNotFound
            Bannote::Studyroomservice::Roomoperatinghour::V1::DeleteRoomOperatingHourResponse.new(
              success: false,
              message: "Room operating hour not found"
            )
          rescue => e
            Bannote::Studyroomservice::Roomoperatinghour::V1::DeleteRoomOperatingHourResponse.new(
              success: false,
              message: "Deletion failed: #{e.message}"
            )
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

          # DB → Proto 변환
          def room_operating_hour_to_proto(operating_hour)
            Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHour.new(
              id: operating_hour.id,
              room_id: operating_hour.room_id,
              day_of_week: operating_hour.day_of_week,
              # 표시용은 HH:MM 으로 포맷, 실제 전달은 Timestamp
              opening_time: Google::Protobuf::Timestamp.new(seconds: operating_hour.opening_time.to_i),
              closing_time: Google::Protobuf::Timestamp.new(seconds: operating_hour.closing_time.to_i),
              created_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.updated_at.to_i),
            )
          end
        end
      end
    end
  end
end
