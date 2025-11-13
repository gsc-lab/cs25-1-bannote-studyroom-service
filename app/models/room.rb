class Room < ApplicationRecord
  # 연관 관계
  has_many :room_operating_hours, dependent: :destroy
  has_many :room_exceptions, dependent: :destroy
  has_many :reservations

  # -------------------------------
  # 필수값 검증
  # -------------------------------
  validates :name, presence: true, length: { maximum: 100 }
  validates :maximum_member, presence: true,
                             numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  # room_type이 enum이라면 자동 처리 
  # enum room_type: { study_room: 0, lecture_room: 1, lab: 2 }, _prefix: :type
  #
  # enum 타입이라면 다음 validation은 안 넣어도 되는데
  # enum이 아니라면 아래처럼 강제해야 함:
  # validates :room_type, inclusion: { in: ["study", "lecture", "lab"] }

  # -------------------------------
  # 이름 중복 검증
  # 1) department_id가 같은 방끼리는 같은 name 금지
  # 2) department_id가 nil(공용 방)일 경우, 전체에서 name 중복 금지
  # -------------------------------
  validate :unique_name_within_department

  def unique_name_within_department
    if department_id.present?
      # 같은 학과 내 중복 name 금지
      if Room.where(department_id: department_id, name: name).where.not(id: id).exists?
        errors.add(:name, "해당 학과에 동일한 이름의 방이 이미 존재합니다.")
      end
    else
      # 공용 방은 전체에서 name 중복 금지
      if Room.where(department_id: nil, name: name).where.not(id: id).exists?
        errors.add(:name, "공용 방 이름은 전체에서 중복될 수 없습니다.")
      end
    end
  end

  # -------------------------------
  # 삭제된 방 수정 금지
  # -------------------------------
  before_update :prevent_update_if_deleted

  def prevent_update_if_deleted
    if deleted_at.present?
      errors.add(:base, "삭제된 방은 수정할 수 없습니다.")
      throw :abort
    end
  end
end
