# frozen_string_literal: true

module SimulatedUserRoles
  # 권한 레벨 정의
  AUTHORITY_LEVELS = {
    "student" => 10,
    "doorkeeper" => 20,
    "class_rep" => 30,
    "assistant" => 50, # 조교
    "professor" => 70, # 교수
    "admin" => 100
  }.freeze
end
