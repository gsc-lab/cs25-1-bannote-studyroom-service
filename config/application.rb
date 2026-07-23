require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module StudyroomService
  class Application < Rails::Application
    config.load_defaults 8.0

    # =====================================================
    # gRPC 폴더 autoload / eager_load 완전 제외 (Rails 8 대응)
    # =====================================================
    initializer :ignore_grpc_from_autoloads, before: :set_autoload_paths do
      grpc_path = Rails.root.join("app/grpc").to_s

      if Dir.exist?(grpc_path)
        Rails.autoloaders.each do |loader|
          loader.ignore(grpc_path) # Zeitwerk autoloader 완전 제외
        end
        config.autoload_paths.delete(grpc_path)
        config.eager_load_paths.delete(grpc_path)
        puts "[Rails] Ignored app/grpc directory from autoload & eager_load"
      else
        puts "[Rails] app/grpc directory not found -> skip ignore"
      end
    end

    # =====================================================
    # API 전용 설정
    # =====================================================
    config.api_only = true

    # =====================================================
    # ActionCable 전체 비활성화 (solid_cable 관련 오류 방지)
    # =====================================================
    config.action_cable.mount_path = nil
    config.action_cable.disable_request_forgery_protection = true
  end
end
