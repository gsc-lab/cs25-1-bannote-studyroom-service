# frozen_string_literal: true

module Bannote
  module Studyroomservice
    module Roomoperatinghour
      module V1
        class RoomOperatingHourServiceHandler < RoomOperatingHourService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # =========================================
          # 1) 전체 조회 (GetRoomOperatingHours)
          # =========================================
          def get_room_operating_hours(request, _call)
            authorize!("student")

            room_id = request.room_id

            hours = ::RoomOperatingHour
                      .where(room_id: room_id, deleted_at: nil)
                      .order(:day_of_week)

            response_hours = hours.map { |h| room_operating_hour_to_proto(h) }

            GetRoomOperatingHoursResponse.new(
              room_operating_hours: response_hours
            )
          end


          # =========================================
          # 2) 리스트 기반 전체 업데이트 (UpdateRoomOperatingHours)
          # =========================================
          def update_room_operating_hours(request, _call)
            authorize!("assistant")

            room_id = request.room_id
            new_items = request.operating_hours.to_a

            # ===== 리스트 내부 중복 방지 =====
            day_list = new_items.map(&:day_of_week)
            if day_list.size != day_list.uniq.size
              raise_invalid("Duplicate day_of_week exists in request list")
            end

            ActiveRecord::Base.transaction do
              existing = ::RoomOperatingHour
                           .where(room_id: room_id, deleted_at: nil)
                           .index_by(&:day_of_week)

              incoming_days = new_items.map(&:day_of_week)

              # A. create + update

              new_items.each do |item|
                validate_day_of_week!(item.day_of_week)
                validate_operating_time_format!(
                  item.opening_time.presence,
                  item.closing_time.presence
                )

                if existing[item.day_of_week]
                  record = existing[item.day_of_week]
                  record.update!(
                    opening_time: item.opening_time.presence,
                    closing_time: item.closing_time.presence,
                    day_maximum_time: item.day_maximum_time.presence
                  )
                else
                  ::RoomOperatingHour.create!(
                    room_id: room_id,
                    day_of_week: item.day_of_week,
                    opening_time: item.opening_time.presence,
                    closing_time: item.closing_time.presence,
                    day_maximum_time: item.day_maximum_time.presence
                  )
                end
              end

              # B. delete (요청에서 빠진 요일)
              existing.each do |dow, record|
                unless incoming_days.include?(dow)
                  record.update!(deleted_at: Time.current)
                end
              end
            end

            Google::Protobuf::Empty.new
          end


          # =========================================
          # 유틸 & 검증
          # =========================================
          private

          def hhmm_to_minutes(hhmm)
            return nil if hhmm.nil?
            h, m = hhmm.split(":").map(&:to_i)
            (h * 60) + m
          end

          def validate_day_of_week!(dow)
            unless dow.between?(0, 6)
              raise_invalid("day_of_week must be between 0 and 6")
            end
          end

          def validate_operating_time_format!(opening, closing)
            opening = opening.presence
            closing = closing.presence

            return if opening.nil? && closing.nil?

            if opening.nil? && closing.present?
              raise_invalid("opening_time is required when closing_time is provided")
            end
            if closing.nil? && opening.present?
              raise_invalid("closing_time is required when opening_time is provided")
            end

            begin
              start_m = hhmm_to_minutes(opening)
              end_m = hhmm_to_minutes(closing)
            rescue
              raise_invalid("Invalid time format. Expected HH:MM")
            end

            if start_m.nil? || end_m.nil?
              raise_invalid("Invalid time format. Expected HH:MM")
            end

            raise_invalid("opening_time must be before closing_time") if start_m >= end_m
          end

          # proto 변환
          def room_operating_hour_to_proto(h)
            RoomOperatingHour.new(
              id: h.id,
              room_id: h.room_id,
              day_of_week: h.day_of_week,
              opening_time: h.opening_time,
              closing_time: h.closing_time,
              day_maximum_time: h.day_maximum_time,
              created_at: to_proto_timestamp(h.created_at),
              updated_at: to_proto_timestamp(h.updated_at),
              deleted_at: nil
            )
          end

          def to_proto_timestamp(time)
            return nil if time.nil?
            Google::Protobuf::Timestamp.new(
              seconds: time.to_i,
              nanos: time.nsec
            )
          end

          # 에러 유틸
          def raise_not_found(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, msg); end
          def raise_invalid(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, msg); end
          def raise_precondition(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, msg); end

          # 권한 체크
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
