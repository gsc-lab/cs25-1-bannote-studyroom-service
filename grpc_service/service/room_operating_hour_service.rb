# frozen_string_literal: true

require 'room_operating_hour/room_operating_hour_pb'
require 'room_operating_hour/service_pb'
require 'room_operating_hour/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Roomoperatinghour
      module V1
        class RoomOperatingHourServiceHandler < Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # HH:MM 검증 함수
          def validate_hhmm!(str)
            raise_invalid("Time must be provided in HH:MM format.") unless str.present?
            begin
              Time.parse(str)
            rescue
              raise_invalid("Invalid time format. Expected HH:MM.")
            end
          end

          # =========================================
          # 1. 운영시간 생성
          # =========================================
          def create_room_operating_hour(request, _call)
            authorize!("assistant")

            room = ::Room.find_by(id: request.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot add operating hours to a deleted room.") if room.deleted_at.present?

            # 요일 중복 금지
            if ::RoomOperatingHour.where(room_id: request.room_id,
                                         day_of_week: request.day_of_week,
                                         deleted_at: nil).exists?
              raise_already_exists("Operating hours for this day already exist.")
            end

            # HH:MM 검증
            validate_hhmm!(request.opening_time)
            validate_hhmm!(request.closing_time)

            # opening < closing 검사
            if Time.parse(request.opening_time) >= Time.parse(request.closing_time)
              raise_invalid("Opening time must be before closing time.")
            end

            operating_hour = ::RoomOperatingHour.create!(
              room_id: request.room_id,
              day_of_week: request.day_of_week,
              opening_time: request.opening_time,   # string 저장
              closing_time: request.closing_time,   # string 저장
              day_maximum_time: request.day_maximum_time.presence,
              created_by: Current.user_code
            )

            Bannote::Studyroomservice::Roomoperatinghour::V1::CreateRoomOperatingHourResponse.new(
              room_operating_hour: room_operating_hour_to_proto(operating_hour)
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
          # 4. 운영시간 수정
          # =========================================
          def update_room_operating_hour(request, _call)
            authorize!("assistant")

            operating_hour = ::RoomOperatingHour.find_by(id: request.id)
            raise_not_found("Room operating hour") unless operating_hour
            raise_precondition("Cannot update deleted operating hour.") if operating_hour.deleted_at.present?

            room = ::Room.find_by(id: operating_hour.room_id)
            raise_not_found("Room") unless room
            raise_precondition("Cannot modify operating hours of a deleted room.") if room.deleted_at.present?

            # 요일 변경 시 중복 체크
            if request.day_of_week.present? &&
               request.day_of_week != operating_hour.day_of_week &&
               ::RoomOperatingHour.where(room_id: operating_hour.room_id,
                                         day_of_week: request.day_of_week,
                                         deleted_at: nil).exists?
              raise_already_exists("Operating hours for this day already exist.")
            end

            # 시간 업데이트 시 검증
            if request.opening_time.present?
              validate_hhmm!(request.opening_time)
            end

            if request.closing_time.present?
              validate_hhmm!(request.closing_time)
            end

            # opening < closing 검사
            if request.opening_time.present? && request.closing_time.present?
              if Time.parse(request.opening_time) >= Time.parse(request.closing_time)
                raise_invalid("Opening time must be before closing time.")
              end
            end

            operating_hour.update!(
              day_of_week: request.day_of_week.presence || operating_hour.day_of_week,
              opening_time: request.opening_time.presence || operating_hour.opening_time,
              closing_time: request.closing_time.presence || operating_hour.closing_time,
              day_maximum_time: request.day_maximum_time.presence || operating_hour.day_maximum_time
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

          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise GRPC::BadStatus.new(
                GRPC::Core::StatusCodes::PERMISSION_DENIED,
                "Permission denied: Requires #{required_role.capitalize} authority or higher."
              )
            end
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

          def raise_already_exists(message)
            raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::ALREADY_EXISTS, message)
          end

          def room_operating_hour_to_proto(operating_hour)
            Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHour.new(
              id: operating_hour.id,
              room_id: operating_hour.room_id,
              day_of_week: operating_hour.day_of_week,
              opening_time: operating_hour.opening_time.to_s,
              closing_time: operating_hour.closing_time.to_s,
              day_maximum_time: operating_hour.day_maximum_time.to_s,
              created_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: operating_hour.updated_at.to_i)
            )
          end

        end
      end
    end
  end
end
