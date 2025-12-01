class AddCodeToReservations < ActiveRecord::Migration[8.0]
  # Temporary model for data migration
  class Reservation < ApplicationRecord
  end

  def change
    add_column :reservations, :code, :string

    # Backfill existing records with a UUID
    Reservation.find_each do |reservation|
      reservation.update!(code: SecureRandom.uuid)
    end

    change_column_null :reservations, :code, false
    add_index :reservations, :code, unique: true
  end
end
