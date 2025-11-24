# frozen_string_literal: true

require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Roomexception
      module V1
        class RoomExceptionServiceHandler < RoomExceptionService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # =========================================
          # 1) 전체 조회
          # =========================================
          def get_room_exceptions(request, _call)
            authorize!("student")

            exceptions = ::RoomException
                           .where(room_id: request.room_id, deleted_at: nil)
                           .order(:holiday_date)

            GetRoomExceptionsResponse.new(
              room_exceptions: exceptions.map { |ex| room_exception_to_proto(ex) }
            )
          end


          # =========================================
          # 2) 리스트 기반 업데이트
          # =========================================
          def update_room_exceptions(request, _call)
            authorize!("assistant")

            room_id = request.room_id
            new_items = request.exceptions.to_a

            # -----------------------------
            # 내부 중복 날짜 검증
            # -----------------------------
            incoming_dates = new_items.map(&:holiday_date).map(&:to_s)
            if incoming_dates.uniq.size != incoming_dates.size
              raise_invalid("Duplicate holiday_date exists in request list")
            end

            ActiveRecord::Base.transaction do
              # DB 기존 데이터 (holiday_date 기준)
              existing = ::RoomException
                           .where(room_id: room_id, deleted_at: nil)
                           .index_by { |ex| ex.holiday_date.to_s }

              # -----------------------------
              # A. create + update
              # -----------------------------
              new_items.each do |item|
                date_str = item.holiday_date.to_s

                # 날짜 검증
                validate_holiday_date!(date_str)

                # 시간 검증
                opening = item.opening_time.presence
                closing = item.closing_time.presence
                validate_exception_time_format!(opening, closing)

                if existing[date_str]
                  # === update ===
                  record = existing[date_str]
                  record.update!(
                    reason: item.reason,
                    opening_time: opening,
                    closing_time: closing
                  )
                else
                  # === create ===
                  ::RoomException.create!(
                    room_id:      room_id,
                    holiday_date: date_str,
                    reason:       item.reason,
                    opening_time: opening,
                    closing_time: closing,
                    created_by:   Current.user_code
                  )
                end
              end

              # -----------------------------
              # B. delete (요청 리스트에 없는 날짜 제거)
              # -----------------------------
              existing.each do |date_str, record|
                unless incoming_dates.include?(date_str)
                  record.update!(deleted_at: Time.current)
                end
              end
            end

            Google::Protobuf::Empty.new
          end


          # =========================================
          # 유틸 / 검증
          # =========================================
          private

          def validate_holiday_date!(date)
            raise_invalid("holiday_date is required") unless date.present?
            Date.parse(date)
          rescue
            raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          def validate_exception_time_format!(opening, closing)
            opening = opening.presence
            closing = closing.presence

            # 둘 다 비어있으면 종일 휴무
            return if opening.nil? && closing.nil?

            if opening.nil? && closing.present?
              raise_invalid("opening_time is required when closing_time is provided")
            end
            if closing.nil? && opening.present?
              raise_invalid("closing_time is required when opening_time is provided")
            end

            begin
              start_t = Time.parse(opening)
              end_t   = Time.parse(closing)
            rescue
              raise_invalid("Invalid time format. Expected HH:MM.")
            end

            raise_invalid("opening_time must be before closing_time") if start_t >= end_t
          end

          # proto 변환
          def room_exception_to_proto(exception)
            RoomException.new(
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

          # 에러
          def raise_invalid(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, msg); end
          def raise_not_found(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, msg); end
          def raise_precondition(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, msg); end

          # 권한 검사
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
