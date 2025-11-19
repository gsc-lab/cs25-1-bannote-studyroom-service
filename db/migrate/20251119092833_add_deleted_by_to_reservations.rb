class AddDeletedByToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :deleted_by, :string
  end
end
