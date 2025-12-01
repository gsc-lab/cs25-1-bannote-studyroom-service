class Room < ApplicationRecord
  # --------------------------------------
  # ?곌? 愿怨?(department_id ?쒓굅)
  # --------------------------------------
  # belongs_to :department  ????젣?댁빞 ??(?댁젣 department ?뚯씠釉붿씠 ?녾린 ?뚮Ц)
  # ?꾩옱 援ъ“?먯꽌??department_id 而щ읆 ?먯껜媛 ?놁쑝誘濡?belongs_to ?쒓굅
  # ?꾩슂?섎㈃ department_code 濡?UserService ?곕룞留??ъ슜

  has_many :room_operating_hours, dependent: :destroy
  has_many :room_exceptions, dependent: :destroy
  has_many :reservations

  # --------------------------------------
  # ?꾩닔媛?寃利?
  # --------------------------------------
  validates :name, presence: true, length: { maximum: 100 }

  validates :maximum_member,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  # --------------------------------------
  # ?대쫫 以묐났 寃利?(department_code 湲곕컲)
  # --------------------------------------
  validate :unique_name_within_department_code

  def unique_name_within_department_code
    if department_code.present?
      # 媛숈? ?숆낵(department_code) ???숈씪 ?대쫫 湲덉?
      if Room.where(department_code: department_code, name: name)
             .where.not(id: id)
             .exists?
        errors.add(:name, "?대떦 ?숆낵???숈씪???대쫫??諛⑹씠 ?대? 議댁옱?⑸땲??")
      end
    else
      # 怨듭슜諛?nil) ???꾩껜?먯꽌 以묐났 湲덉?
      if Room.where(department_code: nil, name: name)
             .where.not(id: id)
             .exists?
        errors.add(:name, "怨듭슜 諛??대쫫? ?꾩껜?먯꽌 以묐났?????놁뒿?덈떎.")
      end
    end
  end

  # --------------------------------------
  # ??젣??諛⑹씠硫??섏젙 湲덉?
  # --------------------------------------
  before_update :prevent_update_if_deleted

  def prevent_update_if_deleted
    if deleted_at.present?
      errors.add(:base, "??젣??諛⑹? ?섏젙?????놁뒿?덈떎.")
      throw :abort
    end
  end
end
