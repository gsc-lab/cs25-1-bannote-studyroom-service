class CreateReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :reservations do |t|
      t.references :room, null: false, foreign_key: true
      t.string :user_name
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps
    end
  end
end
