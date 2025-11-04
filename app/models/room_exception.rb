class RoomException < ApplicationRecord
  # Room 모델과 다대일 관계를 가집니다.
  belongs_to :room

  # Callbacks
  after_save :cancel_conflicting_reservations

  # 유효성 검사 (Validations)
  # room_id, holiday_date, created_by는 필수입니다.
  validates :room_id, presence: true
  validates :holiday_date, presence: true
  validates :created_by, presence: true

  # 소프트 삭제 (Soft Delete)
  # deleted_at 컬럼에 값이 있으면 삭제된 것으로 간주합니다.
  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # RoomException 변경 시 충돌되는 예약을 자동으로 취소하는 로직
  def cancel_conflicting_reservations
    # 변경된 예외 날짜에 해당하는 모든 예약을 조회합니다.
    reservations_on_date = Reservation.where(
      room_id: room_id,
      start_time: holiday_date.all_day
    )

    # Case 1: 완전 휴무일 (운영 시간이 모두 nil)
    if opening_time.nil? && closing_time.nil?
      # 해당 날짜의 모든 예약을 시스템(deleted_by: 0)에 의해 소프트 삭제합니다.
      reservations_on_date.find_each { |reservation| reservation.soft_delete(deleted_by: 0) }
      return
    end

    # Case 2: 특별 운영 시간 지정
    if opening_time.present? && closing_time.present?
      exception_opening_time_str = opening_time.strftime('%H:%M')
      exception_closing_time_str = closing_time.strftime('%H:%M')

      reservations_on_date.find_each do |reservation|
        start_time_str = reservation.start_time.strftime('%H:%M')
        end_time_str = reservation.end_time.strftime('%H:%M')

        # 예약이 새로운 특별 운영 시간의 범위 밖에 있는 경우, 소프트 삭제합니다.
        unless start_time_str >= exception_opening_time_str && end_time_str <= exception_closing_time_str
          reservation.soft_delete(deleted_by: 0)
        end
      end
    end
  end
end