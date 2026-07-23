class Department < ApplicationRecord
  # rooms 테이블은 department_id가 아니라 department_code(문자열)로 참조한다.
  # rooms.department_id는 제거되었고, 대신 department_code/department_name을 사용한다.
  has_many :rooms, foreign_key: :department_code, primary_key: :code
end
