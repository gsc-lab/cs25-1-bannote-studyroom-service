class ReservationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      Rails.logger.info "Received reservation: #{message.payload}"
    end
  end
end
