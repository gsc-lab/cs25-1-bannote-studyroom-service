class AddDeletedAtToRooms < ActiveRecord::Migration[7.1]
  def change
    add_column :rooms, :deleted_at, :datetime
    add_index :rooms, :deleted_at
  end
end
