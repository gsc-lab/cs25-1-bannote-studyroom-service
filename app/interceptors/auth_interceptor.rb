# frozen_string_literal: true

require 'grpc'
require_relative '../../app/models/concerns/current'
require_relative '../../app/models/concerns/simulated_user_roles'   # 吏湲덉? 紐⑸뜲?댄꽣 ?ъ슜

class AuthInterceptor < GRPC::ServerInterceptor
  UNAUTHENTICATED = GRPC::BadStatus.new(
    GRPC::Core::StatusCodes::UNAUTHENTICATED,
    "Unauthenticated: x-user-code metadata is missing"
  )

  def request_response(request:, call:, method:)
    # HealthCheck???몄쬆 ?쒖쇅
    if method.to_s.match?(/Health|health/i)
      return yield
    end

    # ?꾩닔: ?좎? 肄붾뱶
    user_code = call.metadata['x-user-code']
    roles_header = (call.metadata['x-user-role'] || "student").to_s.downcase

    if user_code.nil? || user_code.empty?
      raise UNAUTHENTICATED
    end

    # 沅뚰븳???щ윭 媛??ㅼ뼱?????덉쑝誘濡?諛곗뿴濡?蹂??
    roles = roles_header.split(',').map(&:strip)
    # 紐⑸뜲?댄꽣 ?ъ슜?쇰줈 ?꾨옒 肄붾뱶 ?ъ슜 ?좎? ?쒕퉬???곌껐 ??二쇱꽍泥섎━ or ??젣
    highest_role = roles.max_by { |r| SimulatedUserRoles::AUTHORITY_LEVELS[r] || 0 }

    # 沅뚰븳??enum???ㅼ뼱???섎룄 ?덉쓬 ???レ옄濡?蹂????留ㅽ븨 ?댁빞?섎굹?
    # ?좎? ?쒕퉬???곌껐???꾨옒 肄붾뱶 ?ъ슜
    # roles_enum = roles_header.split(',').map(&:to_i) 
    # roles = roles_enum.map { |v| USER_ROLE_MAP[v] }
    # highest_role = roles.max_by { |r| PRIORITY[r] }

    # 理쒖쥌 ?곸슜
    Current.user_code = user_code
    Current.user_role = highest_role

    puts "[Auth] user_code=#{user_code}, roles=#{roles}, highest_role=#{highest_role}"

    yield

  ensure
    Current.reset
  end
end
