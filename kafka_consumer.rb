require "kafka"

kafka = Kafka.new(["localhost:9095"])

puts "Starting consumer..."


group_id = "studyroom-test-#{rand(100000)}"
consumer = kafka.consumer(group_id: group_id)

puts "Using consumer group: #{group_id}"

consumer.subscribe("test-topic")

consumer.each_message do |msg|
  puts "========== RECEIVED =========="
  puts "topic: #{msg.topic}"
  puts "partition: #{msg.partition}"
  puts "offset: #{msg.offset}"
  puts "value: #{msg.value}"
  puts "================================"
end
