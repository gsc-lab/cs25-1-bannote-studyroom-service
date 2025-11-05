# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :room

  # ========================================
  # Callbacks
  # ========================================
  before_validation :set_defaults
  before_validation :generate_code, on: :create
  before_validation :check_and_handle_reservation_conflicts, on: [:create, :update]

  # ========================================
  # Validations
  # ========================================
  validates :code, presence: true, uniqueness: true
  validates :group_id, presence: true
  validates :purpose, presence: true
  validates :priority, presence: true
  validates :created_by, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :start_time_before_end_time

  # ========================================
  # Default scope (Soft delete)
  # ========================================
  default_scope { where(deleted_at: nil) }

  # ========================================
  # Soft delete method
  # ========================================
  def soft_delete(deleted_by: nil)
    update(deleted_at: Time.current, deleted_by: deleted_by)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # ========================================
  # Default values (NEW)
  # ========================================
  def set_defaults
    self.priority ||= 0
  end

  # ========================================
  # Auto-generate code BEFORE validation
  # ========================================
  def generate_code
    self.code ||= SecureRandom.uuid[0..7]
  end

  # ========================================
  # Custom validation methods
  # ========================================
  def start_time_before_end_time
    return unless start_time && end_time

    if start_time >= end_time
      errors.add(:start_time, "시작 시간은 종료 시간보다 빨라야 합니다.")
    end
  end

  def check_and_handle_reservation_conflicts
    # 운영 시간 확인
    unless is_available_during_operating_hours?
      errors.add(:base, "요청하신 시간은 스터디룸 운영 시간 범위에 포함되지 않거나 휴일입니다.")
      throw :abort
    end

    # 중복 예약 확인
    conflicting_reservations = Reservation.where(room_id: room_id)
                                          .where.not(id: id)
                                          .where("start_time < ? AND end_time > ?", end_time, start_time)

    conflicting_reservations.each do |existing_reservation|
      if priority > existing_reservation.priority
        existing_reservation.soft_delete
      else
        errors.add(:base, "요청하신 시간에 이미 예약이 존재하며, 우선순위가 낮거나 같아 예약할 수 없습니다.")
        throw :abort
      end
    end
  end

  def is_available_during_operating_hours?
    reservation_date = start_time.to_date
    start_time_str = start_time.strftime('%H:%M')
    end_time_str = end_time.strftime('%H:%M')

    # RoomException 우선 확인
    room_exception = room.room_exceptions.find_by(holiday_date: reservation_date)

    if room_exception.present?
      # Case 1: 완전 휴무
      if room_exception.opening_time.nil? && room_exception.closing_time.nil?
        return false
      end

      # Case 2: 특별 운영 시간
      if room_exception.opening_time.present? && room_exception.closing_time.present?
        exception_opening_time_str = room_exception.opening_time.strftime('%H:%M')
        exception_closing_time_str = room_exception.closing_time.strftime('%H:%M')
        return start_time_str >= exception_opening_time_str && end_time_str <= exception_closing_time_str
      end

      # Case 3: 이상 데이터
      return false
    end

    # 일반 운영 시간 확인
    operating_hour = room.room_operating_hours.find_by(day_of_week: start_time.wday)
    return false if operating_hour.nil?

    opening_time_str = operating_hour.opening_time.strftime('%H:%M')
    closing_time_str = operating_hour.closing_time.strftime('%H:%M')

    start_time_str >= opening_time_str && end_time_str <= closing_time_str
  end
end
