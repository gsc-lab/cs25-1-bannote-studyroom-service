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
gem "grpc", "~> 1.57"                # gRPC 통신용
gem "google-protobuf", "~> 3.25"     # ProtoBuf 메시지용
gem "grpc-tools", require: false     # .proto → Ruby 변환용 (buf generate 시 사용)

# ======================================
# [Background Jobs / Cache / Cable]
# ======================================
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"
gem "tzinfo-data"                    # 윈도우 타임존 호환

# ======================================
# [ActiveSupport - Utility Helpers]
# ======================================
gem "activesupport", "~> 8.0"

# ======================================
# [Development & Test]
# ======================================
group :development, :test do
  gem "debug", platforms: [:mri]             # 디버깅
  gem "brakeman", require: false             # 보안 점검
  gem "rubocop-rails-omakase", require: false # 코드 스타일 검사
  gem "dotenv-rails"                         # .env 자동 로드 (필수)
end
