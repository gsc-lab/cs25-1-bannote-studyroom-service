# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'
require_relative '../../grpc_service/common/role_priority'   # 추가

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

    # 받은 값들 중 높은 권한 찾는 로직
    highest_role = RolePriority.highest(roles)

    # 가장 높은 권한으로 적용
    Current.user_code = user_code
    Current.user_role = highest_role

    puts "[AuthInterceptor] user_code=#{user_code}, raw_roles=#{roles}, highest_role=#{highest_role}"

    yield

  ensure
    Current.reset
  end
end
