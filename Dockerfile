ARG RUBY_VERSION=3.1
FROM ruby:${RUBY_VERSION} as base

RUN apt-get update && apt-get install -y vim

FROM base AS builder

RUN mkdir /build
COPY Gemfile spofford-client.gemspec /build
COPY lib/spofford/client/version.rb build/lib/spofford/client/version.rb
WORKDIR /build
RUN bundle config set path /gems && bundle install

FROM base

RUN bundle config set path /gems

WORKDIR /app
