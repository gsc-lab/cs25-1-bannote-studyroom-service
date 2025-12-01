class AddCreatedByToRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :rooms, :created_by, :bigint
  end
end
