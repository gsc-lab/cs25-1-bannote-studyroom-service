# kafka/user_service_consumer.rb

require "kafka"
require "json"

# Kafka broker list
brokers = ["kafka:9092"]

# The topic to subscribe to. This should be the topic where the User Service
# publishes its events. We are using 'user-service-events' as a placeholder.
topic = "user-service-events"

# The consumer group ID. All instances of this consumer will join this group.
group_id = "studyroom-group"

# --- Connection Retry Logic ---
max_retries = 5
retry_delay = 5
retries = 0
kafka = nil

begin
  # Create a new Kafka client instance
  kafka = Kafka.new(brokers, client_id: "studyroom-service")
  puts "Successfully connected to Kafka."
rescue Kafka::ConnectionError => e
  retries += 1
  if retries <= max_retries
    puts "Failed to connect to Kafka: #{e.message}. Retrying in #{retry_delay} seconds... (#{retries}/#{max_retries})"
    sleep retry_delay
    retry
  else
    puts "Could not connect to Kafka after #{max_retries} attempts. Exiting."
    exit 1
  end
end
# --- End of Connection Retry Logic ---

# Create a new consumer instance
consumer = kafka.consumer(group_id: group_id)

# Subscribe to the topic
consumer.subscribe(topic)

puts "Subscribed to '#{topic}' with group ID '#{group_id}'"
puts "Waiting for messages..."

# Trap TERM and INT signals to gracefully shut down the consumer
trap("TERM") { consumer.stop }
trap("INT") { consumer.stop }

begin
  # This will loop indefinitely, fetching and processing messages from the topic.
  consumer.each_message do |message|
    puts "Received message from topic '#{message.topic}' at offset #{message.offset}"
    puts "Key: #{message.key}"
    puts "Value: #{message.value}"

    begin
      # Assuming the message value is a JSON string, parse it.
      payload = JSON.parse(message.value)

      # =================================================================
      # TODO: Implement the logic to process the user service event.
      #
      # What should happen when a user event is received?
      # e.g., Create or update a user record in the studyroom service's database.
      #
      # Example:
      #
      # case payload["event_type"]
      # when "user_created"
      #   User.create!(
      #     uuid: payload["data"]["uuid"],
      #     name: payload["data"]["name"],
      #     email: payload["data"]["email"]
      #   )
      # when "user_updated"
      #   user = User.find_by(uuid: payload["data"]["uuid"])
      #   user.update!(
      #     name: payload["data"]["name"],
      #     email: payload["data"]["email"]
      #   )
      # when "user_deleted"
      #   user = User.find_by(uuid: payload["data"]["uuid"])
      #   user.destroy
      # end
      # =================================================================

      puts "Successfully processed message."

    rescue JSON::ParserError => e
      puts "Failed to parse message value as JSON: #{e.message}"
    rescue => e
      puts "An error occurred while processing the message: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
rescue => e
  puts "Consumer loop terminated with an error: #{e.message}"
ensure
  puts "Consumer stopped."
end
