#!/usr/bin/env ruby
# frozen_string_literal: true

require 'grpc'
require_relative '../config/environment'

# =====================================================
# 1. Rails autoloader 설정
# =====================================================
Rails.autoloaders.main.ignore(Rails.root.join('app/grpc'))

# =====================================================
# 2. gRPC 파일 경로 등록
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
# 5. 서버 실행
# =====================================================
module Bannote
  module Studyroomservice
    module V1
      def self.start
        grpc_port = ENV.fetch('GRPC_PORT', '50053')

        puts "[gRPC] Starting StudyroomService on port #{grpc_port}..."
        puts "[gRPC] Environment: #{ENV.fetch('RAILS_ENV', 'development')}"
        puts "[gRPC] Using database host: #{ENV.fetch('DB_HOST', '(not set)')}"

        # =====================================================
        # 인증 인터셉터 제거 → 메타데이터 없이 호출 가능
        # =====================================================
        server = GRPC::RpcServer.new
        server.add_http2_port("0.0.0.0:#{grpc_port}", :this_port_is_insecure)

        # =====================================================
        # 서비스 핸들러 등록
        # =====================================================
        server.handle(Bannote::Studyroomservice::Room::V1::RoomServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Reservation::V1::ReservationServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomexception::V1::RoomExceptionServiceHandler.new)
        server.handle(Grpc::Health::V1::HealthServer)

        puts "[gRPC] Successfully bound to 0.0.0.0:#{grpc_port}"
        puts "[gRPC] Waiting for incoming requests..."

        # =====================================================
        # 안전한 종료 (SIGINT / SIGTERM 시 종료)
        # =====================================================
        server.run_till_terminated_or_interrupted(['INT', 'TERM'])

        puts "[gRPC] Server stopped cleanly."
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
