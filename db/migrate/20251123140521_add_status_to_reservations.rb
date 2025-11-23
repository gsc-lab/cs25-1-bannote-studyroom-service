class AddStatusToReservations < ActiveRecord::Migration[7.1]
  def change
    add_column :reservations, :status, :integer, default: 1  # 기본값: CONFIRMED
  end
end
