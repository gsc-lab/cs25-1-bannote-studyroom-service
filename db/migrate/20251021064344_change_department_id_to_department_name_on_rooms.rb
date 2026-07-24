class ChangeDepartmentIdToDepartmentNameOnRooms < ActiveRecord::Migration[8.0]
  def change
    # 湲곗〈 ?몃옒?ㅼ슜 而щ읆 ?쒓굅
    remove_column :rooms, :department_id, :bigint if column_exists?(:rooms, :department_id)

    # 臾몄옄??而щ읆 異붽?
    add_column :rooms, :department_name, :string
  end
end
