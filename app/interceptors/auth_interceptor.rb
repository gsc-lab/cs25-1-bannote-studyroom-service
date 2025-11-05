# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: user-id metadata is missing"
  )

  def request_response(request:, call:, method:)
    # ============================================================
    # [변경됨] HealthCheck 요청(Health.Check)은 인증 예외로 통과시킴
    # ============================================================
    if method.to_s.include?("Health.Check")
      puts "[AuthInterceptor] Skipping authentication for Health.Check"
      return yield
    end
    # ============================================================

    # 메타데이터에서 user-id / role 추출
    user_id = call.metadata['user-id'] || call.metadata['user_id']
    role = call.metadata['role']

    # 인증 실패 처리
    if user_id.nil? || user_id.empty?
      raise UNAUTHENTICATED
    end

    # Context 설정
    Current.user_id = user_id
    Current.role = role

    puts "[AuthInterceptor] user_id=#{user_id}, role=#{role}"

    yield
  ensure
    # 요청 후 Context 정리
    Current.reset
  end
end
