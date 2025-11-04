# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: user-id metadata is missing"
  )

  def request_response(request:, call:, method:)
    user_id = call.metadata['user-id'] || call.metadata['user_id']
    role = call.metadata['role']

    if user_id.nil? || user_id.empty?
      raise UNAUTHENTICATED
    end

    # Context 설정
    Current.user_id = user_id
    Current.role = role

    puts "[AuthInterceptor] user_id=#{user_id}, role=#{role}"

    yield
  ensure
    # 요청 후 정리
    Current.reset
  end
end
