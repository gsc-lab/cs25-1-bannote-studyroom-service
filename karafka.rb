class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      'bootstrap.servers': 'kafka:9092'
    }
  end

  consumer_groups.draw do
    topic :reservation_request do
      consumer ReservationConsumer
    end
  end
end
