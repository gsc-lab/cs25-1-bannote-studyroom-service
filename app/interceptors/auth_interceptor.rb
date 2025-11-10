# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  # ------------------------------------------------------------
  # 인증 실패 시 공통 에러 응답 정의
  # ------------------------------------------------------------
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  # ------------------------------------------------------------
  # gRPC 요청 처리 (interceptor entry point)
  # ------------------------------------------------------------
  def request_response(request:, call:, method:)
    # ============================================================
    # 1. HealthCheck 계열 요청은 인증 예외 처리
    # ============================================================
    if method.to_s.match?(/Health|health/i)
      puts "[AuthInterceptor] Skipping authentication for HealthCheck method: #{method}"
      return yield
    end

    # ============================================================
    # 2. 일반 요청은 메타데이터 기반 인증 수행
    # ============================================================
    user_code = call.metadata['x-user-code']
    user_role = call.metadata['x-user-role']

    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    # Current Context 설정
    Current.user_code = user_code
    Current.user_role = user_role

    puts "[AuthInterceptor] user_code=#{user_code}, user_role=#{user_role}"

    # 실제 gRPC 서비스 로직 실행
    yield
  ensure
    # ============================================================
    # 3. 요청 완료 후 Context 정리
    # ============================================================
    Current.reset
  end
end
