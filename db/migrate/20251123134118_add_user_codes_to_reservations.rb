class AddUserCodesToReservations < ActiveRecord::Migration[7.0]
  def change
    # 湲곗〈 user_id ?쒓굅
    if column_exists?(:reservations, :user_id)
      remove_column :reservations, :user_id, :bigint
    end

    # JSON 而щ읆? default 媛믪쓣 ?ㅼ젙?섎㈃ ????(MySQL 洹쒖튃)
    unless column_exists?(:reservations, :user_codes)
      add_column :reservations, :user_codes, :json
    end
  end
end
