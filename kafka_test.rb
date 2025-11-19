require "kafka"

kafka = Kafka.new(["localhost:9095"])

producer = kafka.producer
producer.produce("hello from ruby!", topic: "test-topic")
producer.deliver_messages

puts "sent!"
