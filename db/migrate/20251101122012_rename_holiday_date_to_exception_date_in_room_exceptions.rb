class RenameHolidayDateToExceptionDateInRoomExceptions < ActiveRecord::Migration[7.0]
  def change
    rename_column :room_exceptions, :holiday_date, :exception_date
  end
end
