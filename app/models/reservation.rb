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
  validates :group_id, presence: true
  validates :purpose, presence: true
  validates :priority, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  validate  :start_time_before_end_time

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
  end

  # ========================================
  # Auto-generate code BEFORE validation
  # ========================================
  def generate_code
    # UUID 앞 12자리 사용 (충돌 위험 감소)
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
