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

# require 'healthcheck/healthcheck_pb'

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

        interceptors = [AuthInterceptor.new]
        server = GRPC::RpcServer.new(interceptors: interceptors)
        port = '0.0.0.0:50052'
        server.add_http2_port(port, :this_port_is_insecure)

        server.handle(Bannote::Studyroomservice::Room::V1::RoomServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Reservation::V1::ReservationServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomoperatinghour::V1::RoomOperatingHourServiceHandler.new)
        server.handle(Bannote::Studyroomservice::Roomexception::V1::RoomExceptionServiceHandler.new)
        server.handle(Bannote::CommonService::Healthcheck::HealthServiceHandler)

        puts "gRPC server listening on #{port}"
        server.run_till_terminated
      end
    end
  end
end

Bannote::Studyroomservice::V1.start
