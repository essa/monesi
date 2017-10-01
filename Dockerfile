FROM ruby:2.4.2-slim

RUN apt-get clean && apt-get update \
   && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libxml2 libxslt1.1 libcurl3 libcurl4-openssl-dev\
   && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /monesi
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile $APP_HOME/Gemfile
ADD Gemfile.lock $APP_HOME/Gemfile.lock

RUN bundle install --deployment --without test development

COPY . /monesi
ADD config.yaml config.yaml

VOLUME /envs


