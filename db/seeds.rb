# db/seeds.rb

rooms = [
  { name: "?ㅽ꽣?붾８ A", capacity: 4, maximum_member: 4, status: 0 },
  { name: "?ㅽ꽣?붾８ B", capacity: 6, maximum_member: 6, status: 0 }
]

rooms.each do |room|
  Room.find_or_create_by!(name: room[:name]) do |r|
    r.capacity = room[:capacity]
    r.maximum_member = room[:maximum_member]
    r.status = room[:status]
  end
end

puts "??Room seed data created successfully!"

# -------------------------
# RoomOperatingHour 湲곕낯 ?곗씠??
# -------------------------
rooms = Room.all

rooms.each do |room|
  (1..5).each do |day|  # ??湲?
    RoomOperatingHour.find_or_create_by!(
      room_id: room.id,
      day_of_week: day,
      opening_time: "09:00",
      closing_time: "18:00"
    )
  end
end

puts "??RoomOperatingHour seed created successfully!"
# -------------------------
# RoomException (?댁씪)
# -------------------------
RoomException.find_or_create_by!(
  room_id: Room.first.id,
  holiday_date: "2025-10-25",
  reason: "?뺢린 ?먭?",
  created_by: 1
)

puts "??RoomException seed created successfully!"
