# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :room

  # ========================================
  # 콜백
  # ========================================
  before_validation :set_defaults
  before_validation :generate_code, on: :create

  # ========================================
  # 유효성 검증
  # ========================================
  validates :code, presence: true, uniqueness: true
  validates :purpose, presence: true
  validates :priority, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  validate :start_time_before_end_time

  # group_id는 더 이상 사용하지 않으므로 validation 제거
  # user_id는 제거되고 user_codes(JSON)로 대체됨

  # ========================================
  # 기본 스코프 (Soft delete)
  # ========================================
  default_scope { where(deleted_at: nil) }

  # ========================================
  # Soft delete 메서드
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
  # 기본값
  # ========================================
  def set_defaults
    self.priority ||= 0

    # 매우 중요: MySQL JSON 컬럼은 기본값을 DB에서는 줄 수 없기 때문에
    # Rails에서 기본값을 강제로 주어야 함
    self.user_codes ||= []
  end

  # ========================================
  # 유효성 검증 전 code 자동 생성
  # ========================================
  def generate_code
    # UUID 앞 12자리 사용 (충돌 위험 감소)
    self.code ||= SecureRandom.uuid.delete('-')[0..11]
  end

  # ========================================
  # 시간 검증
  # ========================================
  def start_time_before_end_time
    return unless start_time && end_time

    if start_time >= end_time
      errors.add(:start_time, "must be earlier than end_time")
    end
  end
end
