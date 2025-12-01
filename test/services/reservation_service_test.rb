require 'test_helper'
require 'google/protobuf/timestamp_pb'

class ReservationServiceTest < ActiveSupport::TestCase
  def setup
    @service = ReservationService.new
    @room = Room.create!(name: 'Test Room', department_id: 1, status: :active)

    # ?댁쁺 ?쒓컙: ?붿슂??09:00-18:00
    @operating_day = Date.today.next_occurring(:monday)
    RoomOperatingHour.create!(
      room: @room,
      day_of_week: @operating_day.wday, # Monday
      opening_time: '09:00',
      closing_time: '18:00'
    )

    # ?덉쇅/?댁씪: ?붿슂??
    @holiday_date = Date.today.next_occurring(:tuesday)
    RoomException.create!(
      room: @room,
      holiday_date: @holiday_date,
      reason: 'Maintenance',
      created_by: 1
    )

    # 湲곗〈 ?덉빟: ?섏슂??10:00-11:00
    @booked_day = Date.today.next_occurring(:wednesday)
    # ?섏슂???댁쁺 ?쒓컙??異붽?
    RoomOperatingHour.create!(
      room: @room,
      day_of_week: @booked_day.wday, # Wednesday
      opening_time: '09:00',
      closing_time: '18:00'
    )
    @existing_start = @booked_day.to_time.change(hour: 10)
    @existing_end = @booked_day.to_time.change(hour: 11)
    Reservation.create!(
      room: @room,
      start_time: @existing_start,
      end_time: @existing_end,
      group_id: 1, purpose: 'Existing Meeting', priority: 1, created_by: 1
    )
  end

  # ?깃났 耳?댁뒪
  test "should create reservation on a valid time slot" do
    # ?붿슂??14:00 - 15:00 ?덉빟 ?쒕룄
    start_time = @operating_day.to_time.change(hour: 14)
    end_time = @operating_day.to_time.change(hour: 15)

    request = Studyroom::CreateReservationRequest.new(
      room_id: @room.id,
      group_id: 2,
      start_time: Google::Protobuf::Timestamp.new(seconds: start_time.to_i),
      end_time: Google::Protobuf::Timestamp.new(seconds: end_time.to_i),
      purpose: 'New Meeting',
      priority: 1,
      created_by: 1
    )

    assert_difference('Reservation.count', 1) do
      @service.create_reservation(request, nil)
    end
  end

  # ?ㅽ뙣 耳?댁뒪: ?댁쁺 ?쒓컙 ??
  test "should raise error when booking outside operating hours" do
    # ?붿슂??08:00 - 09:00 ?덉빟 ?쒕룄 (?댁쁺 ?쒖옉 ??
    start_time = @operating_day.to_time.change(hour: 8)
    end_time = @operating_day.to_time.change(hour: 9)

    request = Studyroom::CreateReservationRequest.new(
      room_id: @room.id,
      group_id: 2,
      start_time: Google::Protobuf::Timestamp.new(seconds: start_time.to_i),
      end_time: Google::Protobuf::Timestamp.new(seconds: end_time.to_i),
      purpose: 'Early Meeting',
      priority: 1,
      created_by: 1
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match /outside of the room's standard operating hours/, error.details
  end

  # ?ㅽ뙣 耳?댁뒪: ?댁씪
  test "should raise error when booking on a holiday" do
    # ?붿슂??(?댁씪) 10:00 - 11:00 ?덉빟 ?쒕룄
    start_time = @holiday_date.to_time.change(hour: 10)
    end_time = @holiday_date.to_time.change(hour: 11)

    request = Studyroom::CreateReservationRequest.new(
      room_id: @room.id,
      group_id: 2,
      start_time: Google::Protobuf::Timestamp.new(seconds: start_time.to_i),
      end_time: Google::Protobuf::Timestamp.new(seconds: end_time.to_i),
      purpose: 'Holiday Meeting',
      priority: 1,
      created_by: 1
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match /The room is closed on the selected date/, error.details
  end

  # ?ㅽ뙣 耳?댁뒪: 以묐났 ?덉빟
  test "should raise error for overlapping reservation" do
    # 湲곗〈 ?덉빟: ?섏슂??10:00-11:00
    # 以묐났 ?쒕룄: ?섏슂??10:30-11:30
    start_time = @booked_day.to_time.change(hour: 10, min: 30)
    end_time = @booked_day.to_time.change(hour: 11, min: 30)

    request = Studyroom::CreateReservationRequest.new(
      room_id: @room.id,
      group_id: 3,
      start_time: Google::Protobuf::Timestamp.new(seconds: start_time.to_i),
      end_time: Google::Protobuf::Timestamp.new(seconds: end_time.to_i),
      purpose: 'Overlapping Meeting',
      priority: 1,
      created_by: 1
    )

    error = assert_raises(GRPC::BadStatus) do
      @service.create_reservation(request, nil)
    end

    assert_equal GRPC::Core::StatusCodes::FAILED_PRECONDITION, error.code
    assert_match /The requested time slot is already booked/, error.details
  end
end
