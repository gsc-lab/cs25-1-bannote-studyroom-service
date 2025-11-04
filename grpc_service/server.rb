#!/usr/bin/env ruby
# frozen_string_literal: true

require 'grpc'

# =====================================================
# 1. Rails 환경 로드 + gRPC 폴더 autoload 제외
# =====================================================
require_relative '../config/environment'
Rails.autoloaders.main.ignore(Rails.root.join('app/grpc'))

# =====================================================
# 2. Ruby가 gRPC 파일들을 찾을 수 있도록 경로 추가
# =====================================================
$LOAD_PATH.unshift(File.expand_path('../app/grpc', __dir__))
$LOAD_PATH.unshift(File.expand_path('../app', __dir__))

# =====================================================
# 3. Proto 파일 로드
# =====================================================
require 'room/room_pb'
require 'room/service_pb'
require 'room/service_services_pb'

require 'reservation/reservation_pb'
require 'reservation/service_pb'
require 'reservation/service_services_pb'

require 'room_operating_hour/room_operating_hour_pb'
require 'room_operating_hour/service_pb'
require 'room_operating_hour/service_services_pb'

require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'

require 'healthcheck/healthcheck_pb'
require 'healthcheck/healthcheck_services_pb'

# =====================================================
# 4. 서비스 핸들러 로드
# =====================================================
require_relative 'service/room_service'
require_relative 'service/reservation_service'
require_relative 'service/room_operating_hour_service'
require_relative 'service/room_exception_service'
require_relative 'service/healthcheck_service'

# =====================================================
# 5. gRPC 서버 실행
# =====================================================
module Bannote
  module Studyroomservice
    module V1
      def self.start
        # Rails가 완전히 로드된 이후에 Interceptor 불러오기
        require_relative '../app/interceptors/auth_interceptor'

        # 환경 변수 기반 gRPC 포트 (없으면 기본값 50053)
        grpc_port = ENV.fetch('GRPC_PORT', '50053')

        puts "[gRPC] Starting StudyroomService on port #{grpc_port}..."
        puts "[gRPC] Environment: #{ENV.fetch('RAILS_ENV', 'development')}"
        puts "[gRPC] Using database host: #{ENV.fetch('DB_HOST', '(not set)')}"

        # 서버 초기화
        server = GRPC::RpcServer.new

        # 포트 바인딩
        server.add_http2_port("0.0.0.0:#{grpc_port}", :this_port_is_insecure)

        # 서비스 핸들러 등록 (네임스페이스 주의)
        server.handle(Bannote::Studyroomservice::Room::V1::RoomServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Reservation::V1::ReservationServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomexception::V1::RoomExceptionServiceHandler.new)
        server.handle(Grpc::Health::V1::HealthServer)

        puts "[gRPC] Successfully bound to 0.0.0.0:#{grpc_port}"
        puts "[gRPC] Waiting for incoming requests..."

        # 종료 시그널 핸들링 (서버 안정 종료)
        trap('INT') { server.stop }
        trap('TERM') { server.stop }

        # 서버 실행
        server.run_till_terminated
      rescue => e
        STDERR.puts "[gRPC] Fatal error: #{e.class} - #{e.message}"
        STDERR.puts e.backtrace.join("\n")
        exit 1
      end
    end
  end
end

# =====================================================
# 6. 서버 시작
# =====================================================
Bannote::Studyroomservice::V1.start
