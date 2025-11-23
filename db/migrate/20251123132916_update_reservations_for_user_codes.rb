class FixReservationsUserCodes < ActiveRecord::Migration[7.0]
  def change
    # 1) 기존 단일 user_id 삭제
    if column_exists?(:reservations, :user_id)
      remove_column :reservations, :user_id, :bigint
    end

    # 2) JSON 배열 user_codes 추가
    unless column_exists?(:reservations, :user_codes)
      add_column :reservations, :user_codes, :json, default: []
    end
  end
end
