class RemoveAuditColumnsFromReservations < ActiveRecord::Migration[8.0]
  def change
    remove_column :reservations, :created_by, :bigint if column_exists?(:reservations, :created_by)
    remove_column :reservations, :updated_by, :bigint if column_exists?(:reservations, :updated_by)
    remove_column :reservations, :deleted_by, :bigint if column_exists?(:reservations, :deleted_by)
  end
end
