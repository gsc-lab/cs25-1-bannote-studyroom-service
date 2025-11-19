FROM ruby:3.2

WORKDIR /studyroom_service
COPY . /studyroom_service

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs default-mysql-client wget
RUN gem install bundler rails
RUN bundle install

# Install grpc-health-probe
RUN curl -sSL -o /bin/grpc-health-probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/latest/download/grpc-health-probe-linux-amd64 && \
    chmod +x /bin/grpc-health-probe

EXPOSE 50053
CMD ["ruby", "grpc_service/server.rb"]
