class ChangeOperatingHourTimeColumnTypes < ActiveRecord::Migration[7.0]
  def change
    change_column :room_operating_hours, :opening_time, :string
    change_column :room_operating_hours, :closing_time, :string
    change_column :room_operating_hours, :day_maximum_time, :string
  end
end
