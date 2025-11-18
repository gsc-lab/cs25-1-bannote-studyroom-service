class Room < ApplicationRecord
  # --------------------------------------
  # 연관 관계 (department_id 제거)
  # --------------------------------------
  # belongs_to :department  ← 삭제해야 함 (이제 department 테이블이 없기 때문)
  # 현재 구조에서는 department_id 컬럼 자체가 없으므로 belongs_to 제거
  # 필요하면 department_code 로 UserService 연동만 사용

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
  # 이름 중복 검증 (department_code 기반)
  # --------------------------------------
  validate :unique_name_within_department_code

  def unique_name_within_department_code
    if department_code.present?
      # 같은 학과(department_code) 내 동일 이름 금지
      if Room.where(department_code: department_code, name: name)
             .where.not(id: id)
             .exists?
        errors.add(:name, "해당 학과에 동일한 이름의 방이 이미 존재합니다.")
      end
    else
      # 공용방(nil) → 전체에서 중복 금지
      if Room.where(department_code: nil, name: name)
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
