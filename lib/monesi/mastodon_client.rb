#!/usr/bin/env ruby
# coding: utf-8

require 'bundler/setup'
Bundler.require(:default)

require 'mastodon'
require 'mastodon'
require 'oauth2'
require 'dotenv'
require 'pp'
require 'websocket-client-simple'
require 'json'
require 'uri'
require 'highline/import'
require 'readline'

# some codes are copied from following articles
# http://qiita.com/takahashim/items/a8c0eb3a75d366cfe87b
# http://qiita.com/rerofumi/items/894cde1f57357d2c8479

module Monesi
  class TootDistributer
    attr_reader :client, :queue
    def initialize(client, interval)
      @client = client
      @interval = interval
      @queue = Queue.new
      @cache = LruRedux::TTL::Cache.new(1000, 7 * 24 * 60 * 60) # 2 days ttl cache
    end

    def start
      @thread = Thread.start do
        loop do
          begin
            STDOUT.flush
            toot = queue.pop
            if @cache[toot]
              puts "duplicate toot\n#{toot}"
            else
              puts toot
              client.create_status(toot[0..499], visibility: Config[:visibility])
              @cache[toot] = true
              case queue.size
              when 0
                sleep @interval
              when 1...10
                sleep @interval/queue.size
              else
                # no sleep
              end
            end
          rescue 
            puts $!
            puts $@
          end
        end
      end
    end

    def post(toot)
      queue.push toot
    end
  end

  class MastodonClient
    DEFAULT_APP_NAME = "monesi"
    DEFAULT_MASTODON_URL = 'https://mstdn.jp'
    FULL_ACCESS_SCOPES = "read write"
    def self.setup
      new.setup
    end

    def setup
      Dotenv.load

      if !ENV["MASTODON_URL"]
        ENV["MASTODON_URL"] = ask("Instance URL: "){|q| q.default = DEFAULT_MASTODON_URL}
        File.open(".env", "a+") do |f|
          f.write "MASTODON_URL = '#{ENV["MASTODON_URL"]}'\n"
        end
      end

      scopes = ENV["MASTODON_SCOPES"] || FULL_ACCESS_SCOPES
      app_name = ENV["MASTODON_APP_NAME"] || DEFAULT_APP_NAME

      if !ENV["MASTODON_CLIENT_ID"] || !ENV["MASTODON_CLIENT_SECRET"]
        client = Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"])
        app = client.create_app(app_name, "urn:ietf:wg:oauth:2.0:oob", scopes)
        ENV["MASTODON_CLIENT_ID"] = app.client_id
        ENV["MASTODON_CLIENT_SECRET"] = app.client_secret
        File.open(".env", "a+") do |f|
          f.write "MASTODON_CLIENT_ID = '#{ENV["MASTODON_CLIENT_ID"]}'\n"
          f.write "MASTODON_CLIENT_SECRET = '#{ENV["MASTODON_CLIENT_SECRET"]}'\n"
        end
      end

      if !ENV["MASTODON_ACCESS_TOKEN"]
        client = OAuth2::Client.new(ENV["MASTODON_CLIENT_ID"],
                                    ENV["MASTODON_CLIENT_SECRET"],
                                    site: ENV["MASTODON_URL"])
        login_id = ask("Your Email Address: ")
        password = ask("Your Password: "){|q| q.echo = "*"}
        token = client.password.get_token(login_id, password, scope: scopes)
        ENV["MASTODON_ACCESS_TOKEN"] = token.token
        File.open(".env", "a+") do |f|
          f.write "MASTODON_ACCESS_TOKEN = '#{ENV["MASTODON_ACCESS_TOKEN"]}'\n"
        end
      end
      Config::setup
    end

    def client
      Dotenv.load
      @client ||=
        Mastodon::REST::Client.new(
          base_url: ENV["MASTODON_URL"],
          bearer_token: ENV["MASTODON_ACCESS_TOKEN"]
        )
    end

    def post_message(message, options={})
      options[:visibility] ||= 'unlisted'
      client.create_status(message[0..499], options)
    end

    def watch_stream(&block)
      stream = Mastodon::Streaming::Client.new(
        base_url: ENV["MASTODON_URL"],
        bearer_token: ENV["MASTODON_ACCESS_TOKEN"]
      )
      begin
        stream.user do |toot|
          next unless toot.kind_of?(Mastodon::Notification)
          username = toot.account.username
          host = URI.parse(toot.account.url).host
          text = extract_text(toot.status.content)
          puts "#{username}@#{host}: #{text}"
          block.call(toot, "#{username}@#{host}")
        end
      rescue EOFError
        puts "EOF\nretry..."
        retry
      end

    rescue
      puts $!
      puts $@
      raise
    end

    def console(feed_manager)
      prompt = '> '
      feed_manager.load
      parser = CommandParser.new(feed_manager: feed_manager, debug: true)
      puts parser.help_text
      print prompt
      while cmd = STDIN.gets
        case cmd.chomp
        when 'pry'
          require 'pry'
          binding.pry
        else
          parser.parse(cmd) do |msg| 
            puts msg 
          end
        end
        print prompt
      end
    rescue EOFError
    end

    def echo_server
      setup
      watch_stream do |toot, username| 
        if toot.status.content
          text = extract_text(toot.status.content)
          text.gsub!(/^@\S+/, '')
          client.create_status(text, in_reply_to_id: toot.status.id, visibility: 'unlisted')
          puts text
        end
      end

      loop do
        sleep 1
      end
    end

    def bot(feed_manager)
      Thread.abort_on_exception = true
 
      feed_manager.load

      setup
      parser = CommandParser.new(feed_manager: feed_manager)
      queue = Queue.new
      toot_distributer = TootDistributer.new(client, Config[:interval])
      toot_distributer.start

      Thread.start do
        watch_stream do |toot, username| 
          if toot.type == 'mention' and toot.status.content
            text = extract_text(toot.status.content)
            proc_ = proc do
              puts "received: #{text}"
              parser.parse(text) do |msg| 
                answer = "@#{username}\n#{msg}"
                puts "answer: #{answer}"
                post_message(answer, in_reply_to_id: toot.status.id, visibility: 'direct')
              end
            end
            puts "pushing message event"
            queue.push proc_
          end
        end
      end

      Thread.start do
        puts "fetch thread start"
        loop do
          puts "pushing fetch event"
          proc_ = proc do
            puts "fetching..."
            feed_manager.fetch
            puts "fetched"
            feed_manager.new_entries do |msg| 
              toot_distributer.post(msg)
            end
          end
          queue.push proc_
          sleep 600
        end
      end


      #client.create_status("monesi shared feed reader started")
      loop do
        begin
          puts "popping a proc from queue"
          STDOUT.flush
          proc_ = queue.pop
          puts "popped a proc from queue"
          proc_.call
        rescue 
          puts $!
          puts $@
        end
      end
    end

    private

    def extract_text(content)
      dom = Nokogiri::HTML.parse(content)
      dom.search('p').children.map do |item|
        item.text.strip
      end.join(" ")
    end
  end
end

