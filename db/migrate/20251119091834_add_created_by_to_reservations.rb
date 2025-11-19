class AddCreatedByToReservations < ActiveRecord::Migration[7.0]
  def change
    add_column :reservations, :created_by, :string
  end
end
