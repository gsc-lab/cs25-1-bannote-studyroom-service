# frozen_string_literal: true

module SimulatedUserRoles
  # Define authority levels
  AUTHORITY_LEVELS = {
    "student" => 10,
    "doorkeeper" => 20,
    "class_rep" => 30,
    "assistant" => 50, # 조교
    "professor" => 70, # 교수
    "admin" => 100
  }.freeze
end
