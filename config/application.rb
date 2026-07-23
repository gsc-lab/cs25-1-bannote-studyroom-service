require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module StudyroomService
  class Application < Rails::Application
    config.load_defaults 8.0

    # =====================================================
    # gRPC ?대뜑 autoload / eager_load ?꾩쟾 ?쒖쇅 (Rails 8 ???
    # =====================================================
    initializer :ignore_grpc_from_autoloads, before: :set_autoload_paths do
      grpc_path = Rails.root.join("app/grpc").to_s

      if Dir.exist?(grpc_path)
        Rails.autoloaders.each do |loader|
          loader.ignore(grpc_path) # Zeitwerk autoloader ?꾩쟾 ?쒖쇅
        end
        config.autoload_paths.delete(grpc_path)
        config.eager_load_paths.delete(grpc_path)
        puts "[Rails] Ignored app/grpc directory from autoload & eager_load"
      else
        puts "[Rails] app/grpc directory not found ??skip ignore"
      end
    end

    # =====================================================
    # API ?꾩슜 ?ㅼ젙
    # =====================================================
    config.api_only = true

    # =====================================================
    # ActionCable ?꾩쟾 鍮꾪솢?깊솕 (solid_cable 愿???ㅻ쪟 諛⑹?)
    # =====================================================
    config.action_cable.mount_path = nil
    config.action_cable.disable_request_forgery_protection = true
  end
end
