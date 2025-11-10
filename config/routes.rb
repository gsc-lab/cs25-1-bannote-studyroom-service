Rails.application.routes.draw do
  # Healthcheck endpoints (쿠버네티스 헬스체크용)
  get "/app-health/studyroom-service/livez", to: ->(_) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
  get "/app-health/studyroom-service/readyz", to: ->(_) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }

  # root 기본 라우트
  root to: ->(env) { [200, { "Content-Type" => "text/plain" }, ["Hello from Rails"]] }

  # 방 관련
  resources :rooms

  # 예약 관련
  resources :reservations

  # 운영 시간 관련
  resources :room_operating_hours

  # 예외(휴일, 점검 등) 관련
  resources :room_exceptions
end
