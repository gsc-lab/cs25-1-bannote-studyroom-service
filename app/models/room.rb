class Room < ApplicationRecord
  # --------------------------------------
  # 연관 관계 (department_id 대신 department_code 사용)
  # --------------------------------------
  # rooms.department_id 컬럼은 제거되었고, 이후 departments 테이블이 추가되면서
  # department_code(rooms) <-> code(departments) 로 다시 연결 가능해짐.
  # department_code가 nil이면 공용 방(전체 학과 공용)을 의미하므로 optional.
  belongs_to :department, foreign_key: :department_code, primary_key: :code, optional: true

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
  # 이름 중복 검증 (department_code 기준)
  # --------------------------------------
  validate :unique_name_within_department_code

  def unique_name_within_department_code
    if department_code.present?
      # 같은 학과(department_code) 내 동일 이름 금지
      if Room.where(department_code: department_code, name: name)
             .where.not(id: id)
             .exists?
        errors.add(:name, "해당 학과에는 동일한 이름의 방이 이미 존재합니다.")
      end
    else
      # 공용방(nil) 은 전체에서 중복 금지
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
