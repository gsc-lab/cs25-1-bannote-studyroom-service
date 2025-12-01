require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  # ?뚯뒪?몄뿉 ?ъ슜??湲곕낯 room, ?댁쁺 ?쒓컙, ?덉쇅 ?곗씠?곕? ?ㅼ젙?⑸땲??
  setup do
    @room = rooms(:one) # test/fixtures/rooms.yml ???뺤쓽??:one Room
    
    # ?붿슂??1) 9??18???댁쁺 ?쒓컙 ?ㅼ젙
    @operating_hour = RoomOperatingHour.create!(
      room: @room,
      day_of_week: 1,
      opening_time: Time.parse("09:00"),
      closing_time: Time.parse("18:00")
    )
    
    # ?뱀젙 ?좎쭨(?ㅼ쓬 二??붿슂??瑜??댁씪濡??ㅼ젙
    @next_monday = Date.today.next_occurring(:monday)
    @exception_date = @next_monday + 1.week
    RoomException.create!(
      room: @room,
      holiday_date: @exception_date,
      reason: "Maintenance",
      created_by: 1
    )
  end

  # 1. ?뺤긽?곸씤 ?덉빟 ?앹꽦 ?뚯뒪??
  test "should create reservation if within operating hours and no conflicts" do
    reservation_time = @next_monday.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Team Meeting",
      priority: :medium,
      created_by: 1
    )
    assert reservation.save, "?덉빟???앹꽦?섏뼱???⑸땲?? #{reservation.errors.full_messages.join(", ")}"
  end

  # 2. ?댁쁺 ?쒓컙 ???덉빟 ?쒕룄 ?뚯뒪??(?ㅽ뙣)
  test "should not create reservation outside of operating hours" do
    reservation_time = @next_monday.to_time.change(hour: 8) # 9???댁쟾
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Early Meeting",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "?댁쁺 ?쒓컙 ?몄뿉???덉빟???ㅽ뙣?댁빞 ?⑸땲??"
    assert_includes reservation.errors[:base], "?붿껌?섏떊 ?쒓컙? ?ㅽ꽣?붾８ ?댁쁺 ?쒓컙 踰붿쐞???ы븿?섏? ?딄굅???댁씪?낅땲??"
  end

  # 3. ?댁씪 ?덉빟 ?쒕룄 ?뚯뒪??(?ㅽ뙣)
  test "should not create reservation on a holiday" do
    reservation_time = @exception_date.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time,
      end_time: reservation_time + 1.hour,
      group_id: 1,
      purpose: "Holiday Meeting",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "?댁씪?먮뒗 ?덉빟???ㅽ뙣?댁빞 ?⑸땲??"
    assert_includes reservation.errors[:base], "?붿껌?섏떊 ?쒓컙? ?ㅽ꽣?붾８ ?댁쁺 ?쒓컙 踰붿쐞???ы븿?섏? ?딄굅???댁씪?낅땲??"
  end

  # 4. 湲곗〈 ?덉빟怨??쒓컙??寃뱀튌 ???곗꽑?쒖쐞媛 ??? 寃쎌슦 ?뚯뒪??(?ㅽ뙣)
  test "should not create reservation if time conflicts and priority is lower" do
    # 癒쇱? 湲곗????섎뒗 ?덉빟???앹꽦
    base_time = @next_monday.to_time.change(hour: 11)
    Reservation.create!(
      room: @room,
      start_time: base_time,
      end_time: base_time + 1.hour,
      group_id: 1,
      purpose: "High Prio Meeting",
      priority: :high,
      created_by: 1
    )
    
    # ?곗꽑?쒖쐞媛 ??? ???덉빟???쒕룄
    new_reservation = Reservation.new(
      room: @room,
      start_time: base_time + 30.minutes,
      end_time: base_time + 90.minutes,
      group_id: 2,
      purpose: "Low Prio Meeting",
      priority: :low,
      created_by: 2
    )
    
    assert_not new_reservation.save, "?곗꽑?쒖쐞媛 ??쑝硫?以묐났 ?덉빟???ㅽ뙣?댁빞 ?⑸땲??"
    assert_includes new_reservation.errors[:base], "?붿껌?섏떊 ?쒓컙???대? ?덉빟??議댁옱?섎ŉ, ?곗꽑?쒖쐞媛 ??굅??媛숈븘 ?덉빟?????놁뒿?덈떎."
  end

  # 5. 湲곗〈 ?덉빟怨??쒓컙??寃뱀튌 ???곗꽑?쒖쐞媛 ?믪? 寃쎌슦 ?뚯뒪??(?깃났 諛?湲곗〈 ?덉빟 痍⑥냼)
  test "should create reservation and cancel existing one if priority is higher" do
    # 癒쇱? ?곗꽑?쒖쐞媛 ??? ?덉빟???앹꽦
    base_time = @next_monday.to_time.change(hour: 14)
    existing_reservation = Reservation.create!(
      room: @room,
      start_time: base_time,
      end_time: base_time + 1.hour,
      group_id: 1,
      purpose: "Low Prio Meeting",
      priority: :low,
      created_by: 1
    )
    
    # ?곗꽑?쒖쐞媛 ?믪? ???덉빟???쒕룄
    new_reservation = Reservation.new(
      room: @room,
      start_time: base_time + 30.minutes,
      end_time: base_time + 90.minutes,
      group_id: 2,
      purpose: "High Prio Meeting",
      priority: :high,
      created_by: 2
    )
    
    assert new_reservation.save, "?곗꽑?쒖쐞媛 ?믪쑝硫??덉빟???깃났?댁빞 ?⑸땲?? #{new_reservation.errors.full_messages.join(", ")}"
    
    # 湲곗〈 ?덉빟??soft-delete ?섏뿀?붿? ?뺤씤
    assert_not_nil existing_reservation.reload.deleted_at, "湲곗〈 ?덉빟? soft-delete ?섏뼱???⑸땲??"
  end

  # 6. ?쒖옉 ?쒓컙??醫낅즺 ?쒓컙蹂대떎 ??뒗 寃쎌슦 ?뚯뒪??(?ㅽ뙣)
  test "should not create reservation if start_time is after end_time" do
    reservation_time = @next_monday.to_time.change(hour: 10)
    reservation = Reservation.new(
      room: @room,
      start_time: reservation_time + 1.hour,
      end_time: reservation_time,
      group_id: 1,
      purpose: "Invalid Time",
      priority: :medium,
      created_by: 1
    )
    assert_not reservation.save, "?쒖옉 ?쒓컙??醫낅즺 ?쒓컙蹂대떎 ??쑝硫??덉빟???ㅽ뙣?댁빞 ?⑸땲??"
    assert_includes reservation.errors[:start_time], "?쒖옉 ?쒓컙? 醫낅즺 ?쒓컙蹂대떎 鍮⑤씪???⑸땲??"
  end
end