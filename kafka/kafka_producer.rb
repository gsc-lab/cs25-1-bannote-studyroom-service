require "kafka"

kafka = Kafka.new(["localhost:9092"])

topic = "test-topic"

kafka.deliver_message("hello kafka!", topic: topic)

puts "Message sent!"
