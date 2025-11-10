# app/controllers/healthcheck_controller.rb
class HealthcheckController < ActionController::API
  # Liveness Probe
  def livez
    render plain: "ok", status: :ok
  end

  # Readiness Probe
  def readyz
    render plain: "ok", status: :ok
  end
end
