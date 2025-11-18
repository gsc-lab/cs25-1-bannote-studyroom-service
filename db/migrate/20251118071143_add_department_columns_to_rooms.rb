class AddDepartmentColumnsToRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :rooms, :department_code, :string
    add_column :rooms, :department_name, :string
  end
end
