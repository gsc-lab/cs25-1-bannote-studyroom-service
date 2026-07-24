class AddUserIdToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :user_id, :bigint
  end
end
