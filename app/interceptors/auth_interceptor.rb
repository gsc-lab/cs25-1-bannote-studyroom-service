# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  def request_response(request:, call:, method:)
    # ============================================================
    # HealthCheck 요청은 인증 예외 처리
    # ============================================================
    if method.to_s.include?("Health.Check")
      puts "[AuthInterceptor] Skipping authentication for Health.Check"
      return yield
    end
    # ============================================================

    # 메타데이터에서 user 정보 추출
    user_code = call.metadata['x-user-code']
    user_role = call.metadata['x-user-role']

    # 인증 실패 처리
    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    # Context 설정
    Current.user_code = user_code
    Current.user_role = user_role

    puts "[AuthInterceptor] user_code=#{user_code}, user_role=#{user_role}"

    yield
  ensure
    # 요청 후 Context 정리
    Current.reset
  end
end
