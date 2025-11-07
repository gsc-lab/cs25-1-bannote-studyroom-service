# frozen_string_literal: true 
# 유저 서비스 측으로 MetaData 수정 완료

module Current
  thread_mattr_accessor :user_code
  thread_mattr_accessor :user_role

  def self.reset
    self.user_code = nil
    self.user_role = nil
  end
end
