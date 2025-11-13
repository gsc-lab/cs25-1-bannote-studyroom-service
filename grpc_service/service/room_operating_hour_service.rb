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

            # 방 존재 여부 + 삭제 여부 확인 추가
            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            if room.deleted_at.present?
              raise_precondition("Cannot add operating hours to a deleted room.")
            end

            # 요일 중복 추가
            if ::RoomOperatingHour.where(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              deleted_at: nil
            ).exists?
              raise_already_exists("Operating hours for this day already exist.")
            end

            begin
              opening_time = Time.parse(request.opening_time)
              closing_time = Time.parse(request.closing_time)
            rescue ArgumentError
              raise_invalid("Invalid time format for opening_time or closing_time. Expected HH:MM.")
            end

            raise_invalid("Opening time must be before closing time.") if opening_time >= closing_time

            new_operating_hour = ::RoomOperatingHour.create!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: request.opening_time,
              closing_time: request.closing_time
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::CreateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(new_operating_hour)
            )

          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 2. 단일 조회
          # =========================================
          def get_room_operating_hour(request, _call)
            authorize!("student")

            operating_hour = ::RoomOperatingHour.find_by(id: request.id)
            raise_not_found("Room operating hour") unless operating_hour
            raise_not_found("Room operating hour") if operating_hour.deleted_at.present?

            Bannote::Studyroomservice::Roomoperatinghour::V1::GetRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )
          end

          # =========================================
          # 3. 목록 조회
          # =========================================
          def list_room_operating_hours(request, _call)
            authorize!("student")

            operating_hours = ::RoomOperatingHour.where(deleted_at: nil)
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

            operating_hour = ::RoomOperatingHour.find_by(id: request.id)
            raise_not_found("Room operating hour") unless operating_hour
            raise_precondition("Cannot update deleted operating hour.") if operating_hour.deleted_at.present?

            # 방이 삭제된 방이면 수정도 금지
            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot modify operating hours of a deleted room.") if room.deleted_at.present?

            # 요일 중복 방지 (day_of_week를 수정하는 경우)
            if request.day_of_week.present? &&
               request.day_of_week != operating_hour.day_of_week &&
               ::RoomOperatingHour.where(
                 room_id: request.room_id,
                 day_of_week: request.day_of_week,
                 deleted_at: nil
               ).exists?
              raise_already_exists("Operating hours for this day already exist.")
            end

            # 시간 역전 체크
            if request.opening_time.present? && request.closing_time.present?
              begin
                opening_time = Time.parse(request.opening_time)
                closing_time = Time.parse(request.closing_time)
              rescue ArgumentError
                raise_invalid("Invalid time format for opening_time or closing_time. Expected HH:MM.")
              end

              raise_invalid("Opening time must be before closing time.") if opening_time >= closing_time
            end

            operating_hour.update!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: request.opening_time,
              closing_time: request.closing_time
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::UpdateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
            )

          rescue ActiveRecord::RecordInvalid => e
            raise_invalid(e.message)
          end

          # =========================================
          # 5. 삭제
          # =========================================
          def delete_room_operating_hour(request, _call)
            authorize!("admin")

            operating_hour = ::RoomOperatingHour.find_by(id: request.id)
            raise_not_found("Room operating hour") unless operating_hour
            raise_precondition("Operating hour already deleted.") if operating_hour.deleted_at.present?

            operating_hour.update!(deleted_at: Time.now)

            Bannote::Studyroomservice::Roomoperatinghour::V1::DeleteRoomOperatingHourResponse.new(
              success: true,
              message: "Room operating hour deleted successfully"
            )
          end

          # =========================================
          # 공통 메서드
          # =========================================
          private

          def authorize!(min_role)
            unless SimulatedUserRoles.has_authority?(
              Current.user_code,
              SimulatedUserRoles::AUTHORITY_LEVELS[min_role]
            )
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{min_role.capitalize} authority or higher."
              )
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

          def room_operating_hour_to_proto(operating_hour)
            Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHour.new(
              id: operating_hour.id,
              room_id: operating_hour.room_id,
              day_of_week: operating_hour.day_of_week,
              opening_time: operating_hour.opening_time.strftime("%H:%M"),
              closing_time: operating_hour.closing_time.strftime("%H:%M"),
              created_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.updated_at.to_i)
            )
          end
        end
      end
    end
  end
end
