module Current
  thread_mattr_accessor :user_id, :role

  def self.reset
    self.user_id = nil
    self.role = nil
  end
end
