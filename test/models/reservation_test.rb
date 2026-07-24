require "test_helper"

# 운영 시간 / 휴일 / 중복 예약 검증은 모델이 아니라
# grpc_service/service/reservation_service.rb 에서 처리되므로
# (해당 테스트는 test/services/reservation_service_test.rb 참고),
# 여기서는 모델이 실제로 검증하는 항목만 다룬다.
class ReservationTest < ActiveSupport::TestCase
  setup do
    @room = rooms(:one)
  end

  test "auto-generates a code on create" do
    reservation = Reservation.new(
      room: @room,
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 1.hour,
      purpose: "Team Meeting"
    )

    assert reservation.save, reservation.errors.full_messages.join(", ")
    assert_not_nil reservation.code
  end

  test "requires purpose" do
    reservation = Reservation.new(
      room: @room,
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 1.hour
    )

    assert_not reservation.save
    assert_includes reservation.errors[:purpose], "can't be blank"
  end

  test "requires start_time to be earlier than end_time" do
    reservation = Reservation.new(
      room: @room,
      start_time: 1.day.from_now + 1.hour,
      end_time: 1.day.from_now,
      purpose: "Invalid Time"
    )

    assert_not reservation.save
    assert_includes reservation.errors[:start_time], "must be earlier than end_time"
  end

  test "soft delete hides the reservation from the default scope" do
    reservation = Reservation.create!(
      room: @room,
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 1.hour,
      purpose: "To be cancelled"
    )

    reservation.soft_delete(deleted_by: "tester")

    assert_not_nil reservation.reload.deleted_at
    assert_not_includes Reservation.all, reservation
  end
end
