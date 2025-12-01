class FixReservationsUserCodes < ActiveRecord::Migration[7.0]
  def change
    # 1) 湲곗〈 ?⑥씪 user_id ??젣
    if column_exists?(:reservations, :user_id)
      remove_column :reservations, :user_id, :bigint
    end

    # 2) JSON 諛곗뿴 user_codes 異붽?
    unless column_exists?(:reservations, :user_codes)
      add_column :reservations, :user_codes, :json, default: []
    end
  end
end
