

require "feedbag"
require "feed-normalizer"
require 'aws-sdk'

module Monesi
  module FakeUAForHatena
    # http://q.hatena.ne.jp/1451205850
    def open(url, opt={})
      opt['User-Agent'] = 'Opera/9.80 (Windows NT 5.1; U; ja) Presto/2.7.62 Version/11.01 '
      super(url, opt)
    end
  end
  class ::Feedbag
    include FakeUAForHatena
  end

  class Feed
    include FakeUAForHatena
    attr_reader :feed_url, :title, :entries, :new_entries
    def initialize(feed_url)
      @feed_url = feed_url
      @new_entries = []
    end

    def fetch
      r = FeedNormalizer::FeedNormalizer.parse open(feed_url)
      @title = r.title
      old_entries = @entries
      @entries = r.entries.map do |e| 
        {
          title: e.title.force_encoding("UTF-8"),
          url: e.url.force_encoding("UTF-8"),
          last_updated: e.last_updated
        }
      end

      if old_entries
        urls = old_entries.inject({}) do |h, e| 
          h.merge(e[:url] => true)
        end
        @new_entries = @entries.reject { |e| urls[e[:url]] }
      else
        @new_entries = []
      end
    rescue
      puts "error in fetching #{feed_url}"
      raise
    end
  end

  class FileStorage
    attr_reader :path
    def initialize(path)
      @path = path
    end

    def save(manager)
      File::open(path, 'w') do |f| 
        f.write manager.to_yaml
      end
      puts "feeeds saved to #{path}"
    end

    def load(manager)
      File::open(path) do |f| 
        yaml = YAML::load(f.read)
        manager.restore_from_yaml(yaml)
      end
      puts "feeeds loaded from #{path}"
    rescue Errno::ENOENT
      puts "#{path} not found"
    end
  end

  class S3Storage
    def initialize(bucket_name, options)
      @bucket_name = bucket_name
      @path = options[:path]
    end

    def save(manager)
      s3_client.put_object(
        bucket: @bucket_name,
        key: @path,
        body: manager.to_yaml
      )
      puts "feeds saved to #{@bucket_name} #{@path}"
    end

    def load(manager)
      body = s3_client.get_object(bucket: @bucket_name, key: @path).body.read
      yaml = YAML::load(body)
      manager.restore_from_yaml(yaml)
      puts "feeds loaded from #{@bucket_name} #{@path}"
    rescue Aws::S3::Errors::NoSuchKey
      puts "#{@bucket_name}/#{@path} not found"
    end

    private

    def s3_client
      @s3_client ||= Aws::S3::Client.new
    end
  end

  class FeedManager
    include FakeUAForHatena
    attr_reader :feeds, :storage, :last_fetched
    def initialize(options={})
      @feeds = {}
      @feed_options = {}
      @s3_bucket_name = options[:s3_bucket_name]
      if @s3_bucket_name
        @storage = S3Storage.new(@s3_bucket_name, options)
      else
        @storage = FileStorage.new(options[:path])
      end
      @last_fetched = Time.now
    end

    def save
      storage.save(self)
    end

    def load
      storage.load(self)
    end

    def subscribe(id, url, options={})
      id = id.intern
      feed_url = feed_for(url)
      raise "Feed for #{url} was not found" unless feed_url
      raise "Feed for #{id} is already subscribed" if feeds[id]
      feed = Feed.new(feed_url)
      feed.fetch
      add(id, feed, options)
      save
    end

    def unsubscribe(feed_id)
      remove(feed_id)

      save
    end

    def fetch
      feeds.values.each(&:fetch)
      @last_fetched = Time.now
      save
    end

    def new_entries(&block)
      feeds.each do |feed_id, f| 
        f.new_entries.each do |a| 
          next if filter?(a[:url], feed_id)
          block.call(toot_for_article(feed_id, a))
        end
      end
    end

    def show_articles(feed_id, &block)
      feed = feeds[feed_id]
      raise "feed #{feed_id} not found" unless feed
      feed.entries.each do |a| 
        next if filter?(a[:url], feed_id)
        block.call(toot_for_article(feed_id, a))
      end
    end

    def toot_for_article(feed_id, article)
      tag = feed_option_for(feed_id)[:tag]
      toot = <<~EOS
      #{article[:title]}
      #{article[:url]}
      ##{feed_id}
      EOS
      toot += "\n##{tag}" if tag
      toot
    end

    def show_meta(url, &block)
      dom = Nokogiri::HTML.parse(open(url))
      dom.xpath('//meta').each do |e|
        name = (e['name'] || e['property'])
        value = e['content']
        block.call("#{name} #{value}")
      end
    end

    def filter?(url, feed_id)
      options = feed_option_for(feed_id)
      meta_filter = options[:meta_filter]
      if meta_filter
        ! meta_match?(url, meta_filter)
      else
        false
      end
    end

    def meta_match?(url, meta_filter)
      k = meta_filter.keys.first
      v = meta_filter[k]
      dom = Nokogiri::HTML.parse(open(url))
      dom.xpath('//meta').any? { |e| (e['name'] || e['property']) == k && v === e['content']  }
    end

    def feed_option_for(feed_id)
      @feed_options[feed_id] || {}
    end

    def to_yaml
      {
        feeds: feeds,
        feed_options: @feed_options
      }.to_yaml
    end

    def restore_from_yaml(m)
      @feeds = m[:feeds] || []
      @feed_options = m[:feed_options] || {}
    end

    private
    def feed_for(url)
      feeds = Feedbag.find(url)
      feeds.first
    end

    def add(id, feed, options)
      feeds[id] = feed
      @feed_options[id] = options
    end

    def remove(feed_id)
      feeds.delete(feed_id)
      @feed_options.delete(feed_id)
    end
  end
end
