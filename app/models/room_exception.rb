class RoomException < ApplicationRecord
  belongs_to :room

  after_save :cancel_conflicting_reservations

  # 湲곕낯 ?좏슚??寃??
  validates :room_id, presence: true
  validates :holiday_date, presence: true
  validates :created_by, presence: true

  # 異붽? ?좏슚??寃??
  validate :validate_time_rule
  validate :validate_time_order
  validate :validate_duplicate_date

  # Soft Delete
  default_scope { where(deleted_at: nil) }

  def soft_delete
    update(deleted_at: Time.current)
  end

  def self.with_deleted
    unscope(where: :deleted_at)
  end

  private

  # ----------------------------------------
  # 1) ?꾩껜 ?댁씪 vs 遺遺??댁씪 洹쒖튃
  # ----------------------------------------
  def validate_time_rule
    return if opening_time.nil? && closing_time.nil?

    if opening_time.present? ^ closing_time.present?
      errors.add(:base, "Both opening_time and closing_time must be present for partial holiday")
    end
  end

  # ----------------------------------------
  # 2) ?쒓컙 ?쒖꽌 寃利?(Time.parse ?곸슜)
  # ----------------------------------------
  def validate_time_order
    return if opening_time.blank? || closing_time.blank?

    begin
      ot = Time.parse(opening_time)
      ct = Time.parse(closing_time)

      errors.add(:opening_time, "must be earlier than closing_time") if ot >= ct
    rescue ArgumentError
      errors.add(:base, "Invalid time format (expected HH:MM)")
    end
  end

  # ----------------------------------------
  # 3) ?숈씪 ?좎쭨 以묐났 諛⑹?
  # ----------------------------------------
  def validate_duplicate_date
    return if room_id.blank? || holiday_date.blank?

    duplicate = RoomException
                  .where(room_id: room_id, holiday_date: holiday_date, deleted_at: nil)
                  .where.not(id: id)
                  .exists?

    if duplicate
      errors.add(:holiday_date, "exception already exists for this date")
    end
  end

  # ----------------------------------------
  # 湲곗〈 ?덉빟 ?먮룞 痍⑥냼 濡쒖쭅 (?쒓컙 鍮꾧탳 媛쒖꽑)
  # ----------------------------------------
  def cancel_conflicting_reservations
    reservations_on_date = Reservation.where(
      room_id: room_id,
      start_time: holiday_date.all_day
    )

    # Case 1: ?꾩쟾 ?대Т????紐⑤몢 ??젣
    if opening_time.nil? && closing_time.nil?
      reservations_on_date.find_each { |reservation| reservation.soft_delete(deleted_by: 0) }
      return
    end

    # Case 2: 遺遺??대Т??
    if opening_time.present? && closing_time.present?
      begin
        ex_start = Time.parse(opening_time)
        ex_end   = Time.parse(closing_time)
      rescue ArgumentError
        return
      end

      reservations_on_date.find_each do |reservation|
        r_start = reservation.start_time
        r_end   = reservation.end_time

        # ?덉쇅 ?쒓컙 ?몄뿉 嫄몄튂硫???젣
        unless (r_start >= ex_start && r_end <= ex_end)
          reservation.soft_delete(deleted_by: 0)
        end
      end
    end
  end
end
