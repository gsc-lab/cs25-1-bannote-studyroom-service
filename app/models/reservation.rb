# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :room

  # ========================================
  # Callbacks
  # ========================================
  before_validation :set_defaults
  before_validation :generate_code, on: :create

  # ========================================
  # Validations
  # ========================================
  validates :code, presence: true, uniqueness: true
  validates :purpose, presence: true
  validates :priority, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  validate :start_time_before_end_time

  # group_id?????댁긽 ?ъ슜?섏? ?딆쑝誘濡?validation ?쒓굅
  # user_id???쒓굅????user_codes(JSON)濡??泥대맖

  # ========================================
  # Default scope (Soft delete)
  # ========================================
  default_scope { where(deleted_at: nil) }

  # ========================================
  # Soft delete method
  # ========================================
  def soft_delete(deleted_by: nil)
    update(
      deleted_at: Time.current,
      deleted_by: deleted_by
    )
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # ========================================
  # Default values
  # ========================================
  def set_defaults
    self.priority ||= 0

    # 留ㅼ슦 以묒슂: MySQL JSON 而щ읆? 湲곕낯媛믪쓣 DB?먯꽌??以????녾린 ?뚮Ц??
    # Rails?먯꽌 湲곕낯媛믪쓣 媛뺤젣濡?二쇱뼱????
    self.user_codes ||= []
  end

  # ========================================
  # Auto-generate code BEFORE validation
  # ========================================
  def generate_code
    # UUID ??12?먮━ ?ъ슜 (異⑸룎 ?꾪뿕 媛먯냼)
    self.code ||= SecureRandom.uuid.delete('-')[0..11]
  end

  # ========================================
  # Time validation
  # ========================================
  def start_time_before_end_time
    return unless start_time && end_time

    if start_time >= end_time
      errors.add(:start_time, "must be earlier than end_time")
    end
  end
end
