
# Monesi

Monesi is a bot for Mastodon. You can let it subscribe a rss feed by a mention like "@monesi@bcn-users.degica.com subscribe http://tech.degica.com/".

This project is under heavy development.

## Using Monesi

subscribe a rss feed.

```
@monesi@bcn-users.degica.com subscribe http://tech.degica.com/
```

unsubscribe a rss feed.

```
@monesi@bcn-users.degica.com unsubscribe http://tech.degica.com/
```

list current subscriptions up.

```
@monesi@bcn-users.degica.com list
```

## Installing Monesi

### Requirement

* a dedicated mastodon account
* a server for running it


### Setup

```bash
$ git clone https://github.com/essa/monesi
$ cd monesi
$ bundle install --path vendor/bundle
$ bundle exec rspec spec # test it
$ bundle exec bin/monesi setup
Instance URL: |https://mstdn.jp| https://(your mastodon server)
Your Email Address: (your mail address)
Your Password: ****
```

### Run monesi

```bash
$ bin/monesi bot
```

All subscriptions will be saved to `status.yaml`. 

### Run monesi on [Barcelona](https://github.com/degica/barcelona)

```
$ cp barcelona.yml.sample barcelona.yml
$ vi barcelona.yml # update docker repository url
$ bcn create --district=mstdn -e production
$ bcn env set -e production MASTODON_URL=https://bcn-users.degica.com AWS_REGION=ap-northeast-1 S3_BUCKET=(your S3 bucket name)
$ bcn env set -e production --secret MASTODON_CLIENT_ID='xxxx' MASTODON_CLIENT_SECRET='****' MASTODON_ACCESS_TOKEN='****' AWS_ACCESS_KEY_ID='****' AWS_SECRET_ACCESS_KEY='****' # copy it from .env
$ bcn deploy -e production
```

## Todo

* [ ] Enable Configuration ( Interval for fetching feeds, path for status file, etc...)
* [ ] Access Control List ( Allow subscription only from specified domain/users)
* [ ] Control Logging/Messages
* [ ] Globalize
* [ ] Put a tag on feed update messages

## Why it is named "Monesi"

It is named after another extinct animal like Mastodon.

* [Josephoartigasia monesi \- Wikipedia](https://en.wikipedia.org/wiki/Josephoartigasia_monesi)

