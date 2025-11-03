# grpc_service/service/healthcheck_service.rb

require 'grpc'
require 'healthcheck/healthcheck_pb'
require 'healthcheck/healthcheck_services_pb'

module Bannote
  module CommonService
    module Healthcheck
      class HealthServiceHandler < ::Grpc::Health::V1::Health::Service
        def check(request, _call)
          ::Grpc::Health::V1::HealthCheckResponse.new(status: "SERVING")
        end
      end
    end
  end
end
