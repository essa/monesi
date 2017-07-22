FROM ruby:2.4.1-alpine

RUN echo "@edge https://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
 && apk -U upgrade \
 && apk add git build-base libxml2-dev libxslt-dev

ENV APP_HOME /monesi
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile $APP_HOME/Gemfile
ADD Gemfile.lock $APP_HOME/Gemfile.lock

RUN bundle install --deployment --without test development

COPY . /monesi

VOLUME /envs


