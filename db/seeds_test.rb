puts "?㎥ [TEST] Creating test data..."

# 1. 諛?Room)
room = Room.find_or_create_by!(
  name: "?ㅽ꽣?붾８ A",
  capacity: 4,
  maximum_member: 6,
  status: 0
)
puts "??Room created: #{room.name}"

# 2. ?댁쁺?쒓컙(RoomOperatingHour)
(0..6).each do |day|
  RoomOperatingHour.find_or_create_by!(
    room_id: room.id,
    day_of_week: day,
    opening_time: "09:00",
    closing_time: "18:00",
    created_by: 1
  )
end
puts "???댁쁺?쒓컙???꾩껜 ?붿씪(09:00~18:00)濡??깅줉?덉뒿?덈떎."

# 3. ?댁씪(RoomException)
RoomException.find_or_create_by!(
  room_id: room.id,
  holiday_date: "2025-10-25", # ?좎슂?쇰쭔 ?댁씪濡?吏??
  reason: "?뺢린 ?먭?",
  created_by: 1
)
puts "??RoomException created (2025-10-25)."

# 4. ?덉빟(Reservation) - ?댁쁺?쒓컙 ??(?섏슂??
Reservation.find_or_create_by!(
  room_id: room.id,
  start_time: Time.parse("2025-10-22 10:00"),  # ?됱씪, ?댁쁺?쒓컙 ??
  end_time: Time.parse("2025-10-22 12:00"),
  created_by: 1,
  user_id: 1,
  purpose: "?ㅽ꽣??紐⑥엫",
  priority: 1,
  group_id: 1
)
puts "??Reservation created (?댁쁺?쒓컙 ??."

# 5. ?덉빟(Reservation) - ?댁씪(?뚯뒪?몄슜 ?ㅽ뙣)
begin
  Reservation.create!(
    room_id: room.id,
    start_time: Time.parse("2025-10-25 10:00"),  # ?댁씪
    end_time: Time.parse("2025-10-25 12:00"),
    created_by: 1,
    user_id: 1,
    purpose: "?댁씪 ?뚯뒪??,
    priority: 1,
    group_id: 1
  )
rescue ActiveRecord::RecordInvalid => e
  puts "???댁씪 ?덉빟 ?ㅽ뙣 寃利??깃났: #{e.message}"
end

puts "?렞 TEST SEED validation test completed!"
