class RemoveDepartmentNameAndCodeFromRooms < ActiveRecord::Migration[8.0]
  def change
    remove_column :rooms, :department_name, :string
    remove_column :rooms, :department_code, :string
  end
end
