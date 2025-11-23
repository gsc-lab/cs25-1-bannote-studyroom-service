class AddUserCodesToReservations < ActiveRecord::Migration[7.0]
  def change
    # 기존 user_id 제거
    if column_exists?(:reservations, :user_id)
      remove_column :reservations, :user_id, :bigint
    end

    # JSON 컬럼은 default 값을 설정하면 안 됨 (MySQL 규칙)
    unless column_exists?(:reservations, :user_codes)
      add_column :reservations, :user_codes, :json
    end
  end
end
