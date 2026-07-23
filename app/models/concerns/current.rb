# frozen_string_literal: true

module Current
  thread_mattr_accessor :user_code
  thread_mattr_accessor :user_role

  def self.reset
    self.user_code = nil
    self.user_role = "student" # 湲곕낯 沅뚰븳
  end
end
