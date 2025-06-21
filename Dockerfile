FROM ruby:3.4.4

RUN apt-get update -qq && apt-get install -y build-essential libleveldb-dev
RUN gem install bundler
WORKDIR /app
COPY . /app
RUN bundle install

ENTRYPOINT ["ruby", "wallet.rb"]
