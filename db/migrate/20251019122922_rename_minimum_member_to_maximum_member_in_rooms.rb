class RenameMinimumMemberToMaximumMemberInRooms < ActiveRecord::Migration[7.1]
  def change
    rename_column :rooms, :minimum_member, :maximum_member
  end
end
