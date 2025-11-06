class RemoveAuditColumnsFromReservations < ActiveRecord::Migration[8.0]
  def change
    remove_column :reservations, :created_by, :bigint
    remove_column :reservations, :updated_by, :bigint
    remove_column :reservations, :deleted_by, :bigint
  end
end
