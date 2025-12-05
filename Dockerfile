FROM ruby:3.2

WORKDIR /studyroom_service

# OS packages 먼저 설치
RUN apt-get update -qq && \
    apt-get install -y build-essential default-mysql-client libpq-dev nodejs librdkafka-dev

COPY . /studyroom_service

RUN gem install bundler
RUN bundle install

# grpc-health-probe 설치
RUN curl -sSL -o /bin/grpc-health-probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/latest/download/grpc-health-probe-linux-amd64 && \
    chmod +x /bin/grpc-health-probe

EXPOSE 50053
CMD ["ruby", "grpc_service/server.rb"]
