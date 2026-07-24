require "test_helper"

# grpc_service/service/*.rb 는 app/grpc 를 자체 $LOAD_PATH 에 추가한 뒤
# bare require("reservation/...")로 proto 파일을 불러오므로, 여기서도
# 동일하게 로드 경로를 맞춰준 뒤 핸들러 파일을 직접 require 한다.
grpc_lib_path = Rails.root.join("app/grpc").to_s
$LOAD_PATH.unshift(grpc_lib_path) unless $LOAD_PATH.include?(grpc_lib_path)
require_relative "../../grpc_service/service/reservation_service"

class ReservationServiceTest < ActiveSupport::TestCase
  Handler = Bannote::Studyroomservice::Reservation::V1::ReservationServiceHandler
  RequestMessage = Bannote::Studyroomservice::Reservation::V1::CreateReservationRequest

  setup do
    Current.user_code = "test_admin"
    Current.user_role = "admin"

    @service = Handler.new
    @room = Room.create!(name: "Test Room #{SecureRandom.hex(4)}", maximum_member: 4)

    # 운영 시간: 월요일 09:00-18:00
    @operating_day = Date.today.next_occurring(:monday)
    RoomOperatingHour.create!(
      room: @room,
      day_of_week: @operating_day.wday,
      opening_time: "09:00",
      closing_time: "18:00"
    )

    # 휴일: 화요일
    @holiday_date = Date.today.next_occurring(:tuesday)
    RoomException.create!(
      room: @room,
      holiday_date: @holiday_date,
      reason: "Maintenance",
      created_by: 1
    )

    # 기존 예약: 수요일 10:00-11:00
    @booked_day = Date.today.next_occurring(:wednesday)
    RoomOperatingHour.create!(
      room: @room,
      day_of_week: @booked_day.wday,
      opening_time: "09:00",
      closing_time: "18:00"
    )
    @existing_start = @booked_day.to_time.change(hour: 10)
    @existing_end = @booked_day.to_time.change(hour: 11)
    Reservation.create!(
      room: @room,
      start_time: @existing_start,
      end_time: @existing_end,
      purpose: "Existing Meeting",
      priority: 1,
      user_codes: [ "existing_user" ]
    )
  end

  teardown do
    Current.reset
  end

  test "should create reservation on a valid time slot" do
    start_time = @operating_day.to_time.change(hour: 14)
    end_time = @operating_day.to_time.change(hour: 15)

    request = RequestMessage.new(
      room_id: @room.id,
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      purpose: "New Meeting",
      priority: 1,
      user_codes: [ "new_user" ]
    )

    assert_difference("Reservation.count", 1) do
      @service.create_reservation(request, nil)
    end
  end

  test "should raise error when booking outside operating hours" do
    start_time = @operating_day.to_time.change(hour: 8)
    end_time = @operating_day.to_time.change(hour: 9)

    request = RequestMessage.new(
      room_id: @room.id,
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      purpose: "Early Meeting",
      priority: 1,
      user_codes: [ "new_user" ]
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match(/outside operating hours/, error.details)
  end

  test "should raise error when booking on a holiday" do
    start_time = @holiday_date.to_time.change(hour: 10)
    end_time = @holiday_date.to_time.change(hour: 11)

    request = RequestMessage.new(
      room_id: @room.id,
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      purpose: "Holiday Meeting",
      priority: 1,
      user_codes: [ "new_user" ]
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match(/holiday/, error.details)
  end

  test "should raise error for overlapping reservation" do
    start_time = @booked_day.to_time.change(hour: 10, min: 30)
    end_time = @booked_day.to_time.change(hour: 11, min: 30)

    request = RequestMessage.new(
      room_id: @room.id,
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      purpose: "Overlapping Meeting",
      priority: 1,
      user_codes: [ "new_user" ]
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match(/overlaps/, error.details)
  end

  test "should raise error when user_codes is empty" do
    start_time = @operating_day.to_time.change(hour: 14)
    end_time = @operating_day.to_time.change(hour: 15)

    request = RequestMessage.new(
      room_id: @room.id,
      start_time: start_time.iso8601,
      end_time: end_time.iso8601,
      purpose: "No users"
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::INVALID_ARGUMENT, error.code
  end
end
