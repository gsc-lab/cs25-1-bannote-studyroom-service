# grpc_service/service/healthcheck_service.rb

require 'grpc'
require 'healthcheck/healthcheck_pb'
require 'healthcheck/healthcheck_services_pb'

module Bannote
  module CommonService
    module Healthcheck
      class HealthServiceHandler < ::Grpc::Health::V1::Health::Service
        # 단일 요청 헬스체크
        def check(request, _call)
          puts "[HealthCheck] Service: #{request.service}"
          ::Grpc::Health::V1::HealthCheckResponse.new(status: :SERVING)
        end

        # 스트리밍 요청 헬스체크 (옵션)
        def watch(request, call)
          loop do
            call.send_msg(::Grpc::Health::V1::HealthCheckResponse.new(status: :SERVING))
            sleep 10
          end
        end
      end
    end
  end
end
