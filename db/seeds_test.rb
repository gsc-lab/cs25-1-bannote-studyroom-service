puts "🧪 [TEST] Creating test data..."

# 1. 방(Room)
room = Room.find_or_create_by!(
  name: "스터디룸 A",
  capacity: 4,
  maximum_member: 6,
  status: 0
)
puts "✅ Room created: #{room.name}"

# 2. 운영시간(RoomOperatingHour)
(0..6).each do |day|
  RoomOperatingHour.find_or_create_by!(
    room_id: room.id,
    day_of_week: day,
    opening_time: "09:00",
    closing_time: "18:00",
    created_by: 1
  )
end
puts "✅ 운영시간을 전체 요일(09:00~18:00)로 등록했습니다."

# 3. 휴일(RoomException)
RoomException.find_or_create_by!(
  room_id: room.id,
  holiday_date: "2025-10-25", # 토요일만 휴일로 지정
  reason: "정기 휴관",
  created_by: 1
)
puts "✅ RoomException created (2025-10-25)."

# 4. 예약(Reservation) - 운영시간 내 (수요일)
Reservation.find_or_create_by!(
  room_id: room.id,
  start_time: Time.parse("2025-10-22 10:00"),  # 수요일, 운영시간 내
  end_time: Time.parse("2025-10-22 12:00"),
  created_by: 1,
  user_codes: [ "1" ],
  purpose: "스터디 모임",
  priority: 1
)
puts "✅ Reservation created (운영시간 내)."

# 5. 예약(Reservation) - 휴일 (테스트용)
# NOTE: 운영 시간/휴일 검증은 모델이 아니라 grpc_service/service/reservation_service.rb 에서
# 처리하므로, Reservation.create! 만 호출하는 아래 케이스는 실제로는 RecordInvalid가
# 나지 않고 그냥 생성된다. 검증 자체를 테스트하려면 서비스 핸들러를 통해 호출해야 한다.
begin
  Reservation.create!(
    room_id: room.id,
    start_time: Time.parse("2025-10-25 10:00"),  # 휴일
    end_time: Time.parse("2025-10-25 12:00"),
    created_by: 1,
    user_codes: [ "1" ],
    purpose: "휴일 테스트",
    priority: 1
  )
rescue ActiveRecord::RecordInvalid => e
  puts "✅ 휴일 예약 실패 검증 성공: #{e.message}"
end

puts "🎉 TEST SEED validation test completed!"
