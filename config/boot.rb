ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"

# gRPC 폴더는 autoload 대상에서 제외
grpc_path = File.expand_path("../app/grpc", __dir__)
$LOAD_PATH.delete(grpc_path) if $LOAD_PATH.include?(grpc_path)
