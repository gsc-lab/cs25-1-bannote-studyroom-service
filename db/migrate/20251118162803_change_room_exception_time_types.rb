class ChangeRoomExceptionTimeTypes < ActiveRecord::Migration[7.0]
  def change
    change_column :room_exceptions, :opening_time, :string
    change_column :room_exceptions, :closing_time, :string
  end
end
