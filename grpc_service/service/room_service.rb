# frozen_string_literal: true

require 'room/room_pb'
require 'room/service_pb'
require 'room/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Room
      module V1
        class RoomServiceHandler < Bannote::Studyroomservice::Room::V1::RoomService::Service

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
          # 1. 방 생성
          # =========================================
          def create_room(request, _call)
            authorize!("assistant")

            begin
              room = ::Room.new(
                department_code: request.department_code.present? ? request.department_code.to_s : nil,
                department_name: request.department_name.to_s.strip.presence,
                name: request.name,
                maximum_member: request.maximum_member,
                status: request.status,
                created_by: Current.user_code
              )

              room.save!

              Bannote::Studyroomservice::Room::V1::CreateRoomResponse.new(
                room: room_to_proto(room)
              )

            rescue ActiveRecord::RecordInvalid => e
              raise_invalid(e.record.errors.full_messages.join(", "))
            rescue => e
              raise_internal("Failed to create room: #{e.message}")
            end
          end

          # =========================================
          # 2. 방 단일 조회
          # =========================================
          def get_room(request, _call)
            authorize!("student")

            room = ::Room.find_by(id: request.id)
            raise_not_found("Room") unless room
            raise_not_found("Room") if room.deleted_at.present?

            Bannote::Studyroomservice::Room::V1::GetRoomResponse.new(
              room: room_to_proto(room)
            )
          end

          # =========================================
          # 3. 방 목록 조회 (페이지네이션)
          # =========================================
          def list_rooms(request, _call)
            authorize!("assistant")

            page      = request.page.to_i <= 0 ? 1 : request.page.to_i
            page_size = request.page_size.to_i <= 0 ? 20 : request.page_size.to_i
            offset    = (page - 1) * page_size

            total_count = ::Room.where(deleted_at: nil).count

            rooms = ::Room
                      .where(deleted_at: nil)
                      .order(created_at: :desc)
                      .offset(offset)
                      .limit(page_size)

            room_responses = rooms.map { |room| room_to_proto(room) }

            Bannote::Studyroomservice::Room::V1::ListRoomsResponse.new(
              rooms: room_responses,
              total_count: total_count,
              page: page,
              page_size: page_size
            )
          end

          # =========================================
          # 4. 방 수정
          # =========================================
          def update_room(request, _call)
            authorize!("assistant")

            room = ::Room.find_by(id: request.id)
            raise_not_found("Room") unless room
            raise_not_found("Room") if room.deleted_at.present?

            begin
              room.update!(
                department_code: request.department_code.presence || room.department_code,
                department_name: request.department_name.presence || room.department_name,
                name: request.name || room.name,
                maximum_member: request.maximum_member || room.maximum_member,
                status: request.status
              )

              Bannote::Studyroomservice::Room::V1::UpdateRoomResponse.new(
                room: room_to_proto(room)
              )

            rescue ActiveRecord::RecordInvalid => e
              raise_invalid(e.record.errors.full_messages.join(", "))
            end
          end

          # =========================================
          # 5. 방 삭제 (Soft Delete)
          # =========================================
          def delete_room(request, _call)
            authorize!("assistant")

            room = ::Room.find_by(id: request.id)
            raise_not_found("Room") unless room
            raise_not_found("Room") if room.deleted_at.present?

            room.update!(deleted_at: Time.now)

            Bannote::Studyroomservice::Room::V1::DeleteRoomResponse.new
          end

          # =========================================
          # 공통 메서드
          # =========================================
          private

          def authorize!(required_role)
            user_role = Current.user_role.to_s

            unless ROLE_PRIORITY[user_role] &&
                   ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise_permission("Requires #{required_role.capitalize} authority or higher.")
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

          def raise_permission(message)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::PERMISSION_DENIED,
              message
            )
          end

          def raise_internal(message)
            raise GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::INTERNAL,
              message
            )
          end

          # Room → Proto 변환 (timestamp 포함)
          def room_to_proto(room)
            Bannote::Studyroomservice::Room::V1::Room.new(
              id: room.id,
              department_code: room.department_code.to_s,
              department_name: room.department_name.to_s,
              name: room.name,
              maximum_member: room.maximum_member,
              status: room.status,
              created_at: Google::Protobuf::Timestamp.new(seconds: room.created_at.to_i, nanos: room.created_at.nsec),
              updated_at: Google::Protobuf::Timestamp.new(seconds: room.updated_at.to_i, nanos: room.updated_at.nsec),
              created_by: room.created_by
            )
          end

        end
      end
    end
  end
end
