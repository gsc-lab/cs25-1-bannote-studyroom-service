class RoomException < ApplicationRecord
  # Room 모델과 다대일 관계를 가집니다.
  belongs_to :room

  # Callbacks
  after_save :cancel_conflicting_reservations

  # 기본 유효성 검사
  validates :room_id, presence: true
  validates :holiday_date, presence: true
  validates :created_by, presence: true

  # 추가 유효성 검사
  validate :validate_time_rule
  validate :validate_time_order
  validate :validate_duplicate_date

  # 소프트 삭제 (Soft Delete)
  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # ----------------------------------------
  # 1) 전체 휴일 vs 부분 휴일 규칙
  # ----------------------------------------
  def validate_time_rule
    # 전체 휴일 (both nil) → OK
    return if opening_time.nil? && closing_time.nil?

    # 부분 휴일 → 둘 다 있어야 함
    if opening_time.present? ^ closing_time.present?
      errors.add(:base, "Both opening_time and closing_time must be present for partial holiday")
    end
  end

  # ----------------------------------------
  # 2) 시간 순서 검증
  # ----------------------------------------
  def validate_time_order
    return if opening_time.blank? || closing_time.blank?

    if opening_time >= closing_time
      errors.add(:opening_time, "must be earlier than closing_time")
    end
  end

  # ----------------------------------------
  # 3) 동일 날짜 중복 방지 (soft-delete 제외)
  # ----------------------------------------
  def validate_duplicate_date
    return if room_id.blank? || holiday_date.blank?

    duplicate = RoomException.with_deleted
                             .where(room_id: room_id, holiday_date: holiday_date, deleted_at: nil)
                             .where.not(id: id)
                             .exists?

    if duplicate
      errors.add(:holiday_date, "exception already exists for this date")
    end
  end

  # ----------------------------------------
  # 기존 예약 자동 취소 로직 (그대로 유지)
  # ----------------------------------------
  def cancel_conflicting_reservations
    reservations_on_date = Reservation.where(
      room_id: room_id,
      start_time: holiday_date.all_day
    )

    # Case 1: 완전 휴무일
    if opening_time.nil? && closing_time.nil?
      reservations_on_date.find_each { |reservation| reservation.soft_delete(deleted_by: 0) }
      return
    end

    # Case 2: 부분 휴무
    if opening_time.present? && closing_time.present?
      exception_opening_time_str = opening_time.strftime('%H:%M')
      exception_closing_time_str = closing_time.strftime('%H:%M')

      reservations_on_date.find_each do |reservation|
        start_time_str = reservation.start_time.strftime('%H:%M')
        end_time_str = reservation.end_time.strftime('%H:%M')

        unless start_time_str >= exception_opening_time_str &&
               end_time_str <= exception_closing_time_str
          reservation.soft_delete(deleted_by: 0)
        end
      end
    end
  end
end
