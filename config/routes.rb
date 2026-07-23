Rails.application.routes.draw do
  # ======================================
  # Healthcheck endpoints (荑좊쾭?ㅽ떚???ъ뒪泥댄겕??
  # ======================================
  get "/app-health/studyroom-service/livez", to: ->(_) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
  get "/app-health/studyroom-service/readyz", to: ->(_) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }

  # ======================================
  # 湲곕낯 ?쇱슦??
  # ======================================
  root to: ->(env) { [200, { "Content-Type" => "text/plain" }, ["Hello from Rails"]] }

  # ======================================
  # 湲곕뒫蹂?API ?쇱슦??
  # ======================================
  # 諛?愿??
  resources :rooms

  # ?덉빟 愿??
  resources :reservations

  # ?댁쁺 ?쒓컙 愿??
  resources :room_operating_hours

  # ?덉쇅(?댁씪, ?먭? ?? 愿??
  resources :room_exceptions
end
