class AddDepartmentIdToRooms < ActiveRecord::Migration[8.0]
  def change
    add_reference :rooms, :department, null: true, foreign_key: true
  end
end
