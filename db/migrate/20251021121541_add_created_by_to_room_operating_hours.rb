class AddCreatedByToRoomOperatingHours < ActiveRecord::Migration[8.0]
  def change
    add_column :room_operating_hours, :created_by, :bigint
    add_column :room_operating_hours, :updated_by, :bigint
    add_column :room_operating_hours, :deleted_by, :bigint
  end
end
