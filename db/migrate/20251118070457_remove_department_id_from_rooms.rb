class RemoveDepartmentIdFromRooms < ActiveRecord::Migration[7.0]
  def change
    remove_column :rooms, :department_id, :bigint
  end
end
