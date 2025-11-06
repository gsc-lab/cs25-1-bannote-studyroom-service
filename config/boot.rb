ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"

# gRPC 폴더 autoload 방지
grpc_path = File.expand_path("../app/grpc", __dir__)
$LOAD_PATH.delete(grpc_path) if $LOAD_PATH.include?(grpc_path)
