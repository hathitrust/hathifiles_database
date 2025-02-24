FROM ruby:3.4

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  mariadb-client

WORKDIR /usr/src/app
ENV BUNDLE_PATH /gems
RUN gem install bundler
