# Gemfile
source "https://rubygems.org"

# ======================================
# [Core Framework]
# ======================================
gem "rails", "~> 8.0.3"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# ======================================
# [Database]
# ======================================
gem "mysql2", "~> 0.5"

# ======================================
# [gRPC & Protocol Buffers]
# ======================================
gem "grpc", "~> 1.76" # 특정 플랫폼 지정을 제거하고 Bundler가 현재 환경에 맞는 네이티브 gem을 설치하도록 합니다.
gem "google-protobuf", "~> 3.25"
gem "grpc-tools", require: false

# ======================================
# [Background Jobs / Cache / Cable] (필요 시 유지)
# ======================================
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"
gem "tzinfo-data"

# ======================================
# [Development & Test]
# ======================================
group :development, :test do
  gem "debug", platforms: [:mri]
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

gem 'tzinfo-data'

gem "activesupport", "~> 8.0"
