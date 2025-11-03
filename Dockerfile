FROM ruby:3.2

WORKDIR /rails
COPY . /rails

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs default-mysql-client
RUN gem install bundler rails
RUN bundle install

EXPOSE 50053
CMD ["ruby", "grpc_service/server.rb"]
