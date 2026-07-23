# frozen_string_literal: true

require 'grpc'
require 'healthcheck/healthcheck_pb'
require 'healthcheck/healthcheck_services_pb'

module Grpc
  module Health
    module V1
      class HealthServer < Health::Service
        def check(request, _call)
          response = HealthCheckResponse.new(
            status: HealthCheckResponse::ServingStatus::SERVING
          )
          response
        end

        def watch(request, _call)
          # Health streaming? 蹂댄넻 ???곗씠誘濡?NotImplemented 泥섎━
          raise GRPC::BadStatus.new_status_exception(
            GRPC::Core::StatusCodes::UNIMPLEMENTED,
            'Watch not implemented'
          )
        end
      end
    end
  end
end
