# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'   # 지금은 목데이터 사용

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  def request_response(request:, call:, method:)
    # HealthCheck는 인증 제외
    if method.to_s.match?(/Health|health/i)
      return yield
    end

    # 필수: 유저 코드
    user_code = call.metadata['x-user-code']
    roles_header = (call.metadata['x-user-role'] || "student").to_s.downcase

    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    # 권한이 여러 개 들어올 수 있으므로 배열로 변환
    roles = roles_header.split(',').map(&:strip)
    # 목데이터 사용으로 아래 코드 사용 유저 서비스 연결 시 주석처리 or 삭제
    highest_role = roles.max_by { |r| SimulatedUserRoles::AUTHORITY_LEVELS[r] || 0 }

    # 권한이 enum이 들어올 수도 있음 → 숫자로 변환 후 매핑 해야하나?
    # 유저 서비스 연결시 아래 코드 사용
    # roles_enum = roles_header.split(',').map(&:to_i) 
    # roles = roles_enum.map { |v| USER_ROLE_MAP[v] }
    # highest_role = roles.max_by { |r| PRIORITY[r] }

    # 최종 적용
    Current.user_code = user_code
    Current.user_role = highest_role

    puts "[Auth] user_code=#{user_code}, roles=#{roles}, highest_role=#{highest_role}"

    yield

  ensure
    Current.reset
  end
end
