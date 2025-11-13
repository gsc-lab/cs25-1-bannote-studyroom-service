class RoomOperatingHour < ApplicationRecord
  # Room 모델과 다대일 관계
  belongs_to :room

  # 기본 유효성 검사
  validates :room_id, presence: true
  validates :day_of_week, presence: true, numericality: { only_integer: true, in: 0..6 }
  validates :opening_time, presence: true
  validates :closing_time, presence: true

  # 추가 유효성 검사 (예외 처리)
  validate :validate_time_order
  validate :validate_day_of_week_duplication

  # 소프트 삭제
  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # ----------------------------------------
  # 1. opening_time < closing_time 검증
  # ----------------------------------------
  def validate_time_order
    return if opening_time.blank? || closing_time.blank?

    if opening_time >= closing_time
      errors.add(:opening_time, "must be earlier than closing_time")
    end
  end

  # ----------------------------------------
  # 2. 동일 room_id + day_of_week 중복 금지
  # ----------------------------------------
  def validate_day_of_week_duplication
    return if room_id.blank? || day_of_week.blank?

    duplicate = RoomOperatingHour.with_deleted
                                 .where(room_id: room_id, day_of_week: day_of_week, deleted_at: nil)
                                 .where.not(id: id)
                                 .exists?

    if duplicate
      errors.add(:day_of_week, "already exists for this room")
    end
  end
end
