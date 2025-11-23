# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  def request_response(request:, call:, method:)
    if method.to_s.match?(/Health|health/i)
      puts "[AuthInterceptor] Skipping authentication for HealthCheck method: #{method}"
      return yield
    end

    user_code = call.metadata['x-user-code']
    user_role = (call.metadata['x-user-role'] || "student").to_s.downcase

    roles = user_role.split(',').map { |r| r.strip }

    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    Current.user_code = user_code
    Current.user_role = user_role

    puts "[AuthInterceptor] user_code=#{user_code}, user_role=#{user_role}"

    yield

  ensure
    Current.reset
  end
end
