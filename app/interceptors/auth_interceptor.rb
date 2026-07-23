# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  # UserRole enum 뒤 값 → 내부 authorize! 로 쓰는 문자열 매핑
  ROLE_MAP = {
    "STUDENT"    => "student",
    "DOORKEEPER" => "doorkeeper",
    "CLASS_REP"  => "class_rep",
    "TA"         => "assistant",
    "PROFESSOR"  => "professor",
    "ADMIN"      => "admin",
    "DEFAULT"    => "student"
  }.freeze

  def request_response(request:, call:, method:)
    # HealthCheck???몄쬆 ?쒖쇅
    if method.to_s.match?(/Health|health/i)
      return yield
    end

    user_code = call.metadata['x-user-code']
    raw_roles = (call.metadata['x-user-role'] || "STUDENT").upcase

    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    # 여러 권한이면 쉼표 기반 분리
    role_keys = raw_roles.split(",").map(&:strip)

    # 서버에서 넘어온 enum 뒤 값 → 내부 role 로 매핑
    mapped_roles = role_keys.map { |key| ROLE_MAP[key] || "student" }

    # SimulatedUserRoles 로 가장 높은 권한 찾기
    highest_role = mapped_roles.max_by { |r| SimulatedUserRoles::AUTHORITY_LEVELS[r] || 0 }

    # Current에 저장
    Current.user_code = user_code
    Current.user_role = highest_role

    puts "[Auth] user_code=#{user_code}, raw_roles=#{role_keys}, mapped_roles=#{mapped_roles}, highest_role=#{highest_role}"

    yield

  ensure
    Current.reset
  end
end
