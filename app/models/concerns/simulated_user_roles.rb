# frozen_string_literal: true

module SimulatedUserRoles
  # Define authority levels
  AUTHORITY_LEVELS = {
    "student" => 10,
    "doorkeeper" => 20,
    "class_rep" => 30,
    "assistant" => 50, # 議곌탳
    "professor" => 70, # 援먯닔
    "admin" => 100
  }.freeze

  # Map user_id to a simulated role for development purposes
  # In a real application, this would come from a user management service or database
  SIMULATED_USERS = {
    "user_admin" => "admin",
    "user_assistant" => "assistant",
    "user_professor" => "professor",
    "user_class_rep" => "class_rep",
    "user_doorkeeper" => "doorkeeper",
    "user_student" => "student",
    "unknown_user" => "student" # Default for unknown users
  }.freeze

  def self.get_authority_level(user_id)
    role = SIMULATED_USERS[user_id] || SIMULATED_USERS["unknown_user"]
    AUTHORITY_LEVELS[role]
  end

  def self.has_authority?(user_id, required_level)
    get_authority_level(user_id) >= required_level
  end
end
