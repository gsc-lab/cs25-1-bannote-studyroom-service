class Room < ApplicationRecord
  # --------------------------------------
  # 연관 관계
  # --------------------------------------
  belongs_to :department, optional: true   # 기존 데이터와의 호환 위해 optional
                                           # 나중에 전부 채워지면 optional: false 로 변경 가능

  has_many :room_operating_hours, dependent: :destroy
  has_many :room_exceptions, dependent: :destroy
  has_many :reservations

  # --------------------------------------
  # 필수값 검증
  # --------------------------------------
  validates :name, presence: true, length: { maximum: 100 }

  validates :maximum_member,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  # --------------------------------------
  # 이름 중복 검증
  # 1) department_id가 있는 경우 → 같은 학과 내에서 이름 중복 금지
  # 2) department_id가 없는 경우(nil) → 공용 방, 전체에서 이름 중복 금지
  # --------------------------------------
  validate :unique_name_within_department

  def unique_name_within_department
    if department_id.present?
      # 같은 학과 내 동일 이름 금지
      if Room.where(department_id: department_id, name: name)
              .where.not(id: id)
              .exists?
        errors.add(:name, "해당 학과에 동일한 이름의 방이 이미 존재합니다.")
      end
    else
      # 공용방(nil) → 전체에서 중복 금지
      if Room.where(department_id: nil, name: name)
              .where.not(id: id)
              .exists?
        errors.add(:name, "공용 방 이름은 전체에서 중복될 수 없습니다.")
      end
    end
  end

  # --------------------------------------
  # 삭제된 방이면 수정 금지
  # --------------------------------------
  before_update :prevent_update_if_deleted

  def prevent_update_if_deleted
    if deleted_at.present?
      errors.add(:base, "삭제된 방은 수정할 수 없습니다.")
      throw :abort
    end
  end
end
