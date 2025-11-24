module Bannote
  module Studyroomservice
    module Roomoperatinghour
      module V1
        class RoomOperatingHourServiceHandler < RoomOperatingHourService::Service

          # ---------------------------------------------------------
          # 1. 전체 조회 (GetRoomOperatingHours)
          # ---------------------------------------------------------
          def get_room_operating_hours(request, _call)
            room_id = request.room_id

            hours = ::RoomOperatingHour
                      .where(room_id: room_id, deleted_at: nil)
                      .order(:day_of_week)

            response_hours = hours.map do |h|
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

            GetRoomOperatingHoursResponse.new(
              room_operating_hours: response_hours
            )
          end


          # ---------------------------------------------------------
          # 2. 리스트 기반 업데이트 (UpdateRoomOperatingHours)
          # ---------------------------------------------------------
          def update_room_operating_hours(request, _call)
            room_id = request.room_id

            new_items = request.operating_hours.to_a

            ActiveRecord::Base.transaction do
              # DB 기존 항목
              existing = ::RoomOperatingHour
                           .where(room_id: room_id, deleted_at: nil)
                           .index_by(&:id)

              # 신규 리스트에서 사용된 id 목록
              received_ids = new_items.map(&:id).reject(&:zero?)

              # -----------------------------
              # A. 생성 + 업데이트 처리
              # -----------------------------
              new_items.each do |item|
                if item.id != 0 && existing[item.id]
                  # ===== 1) 기존 항목 → 업데이트 =====
                  record = existing[item.id]
                  record.update!(
                    day_of_week: item.day_of_week,
                    opening_time: item.opening_time,
                    closing_time: item.closing_time,
                    day_maximum_time: item.day_maximum_time
                  )

                else
                  # ===== 2) 신규 항목 → 생성 =====
                  ::RoomOperatingHour.create!(
                    room_id: room_id,
                    day_of_week: item.day_of_week,
                    opening_time: item.opening_time,
                    closing_time: item.closing_time,
                    day_maximum_time: item.day_maximum_time
                  )
                end
              end

              # -----------------------------
              # B. 삭제 처리 (DB에는 있는데 새 리스트엔 없음)
              # -----------------------------
              ids_to_delete = existing.keys - received_ids

              ::RoomOperatingHour.where(id: ids_to_delete)
                                 .update_all(deleted_at: Time.current)
            end

            Google::Protobuf::Empty.new
          end



          # ---------------------------------------------------------
          # 유틸: Ruby Time → gRPC Timestamp 변환
          # ---------------------------------------------------------
          private

          def to_proto_timestamp(time)
            return nil if time.nil?

            Google::Protobuf::Timestamp.new(
              seconds: time.to_i,
              nanos:   time.nsec
            )
          end

        end
      end
    end
  end
end
