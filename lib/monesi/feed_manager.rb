

require "feedbag"
require "feed-normalizer"

module Monesi
  class Feed
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
    end
  end

  class FeedManager
    attr_reader :feeds, :storage, :last_fetched
    def initialize(options={})
      @feeds = []
      @storage = FileStorage.new(options[:path])
      @last_fetched = Time.now
    end

    def save
      storage.save(self)
    end

    def load
      storage.load(self)
    end

    def subscribe(url)
      feed_url = feed_for(url)
      raise "Feed for #{url} was not found" unless feed_url
      raise "Feed for #{url} is already subscribed" if feeds.any? { |f| f.feed_url == feed_url}
      feed = Feed.new(feed_url)
      feed.fetch
      add(feed)
      save
    end

    def unsubscribe(url)
      feed_url = feed_for(url)
      raise "Feed for #{url} was not found" unless feed_url

      i = feeds.find_index do |f| 
        f.feed_url == feed_url
      end
      raise "Feed #{url} is not subscribed" unless i

      feeds.delete_at(i)
      save
    end

    def restore_from_yaml(m)
      @feeds = m.feeds
    end

    def fetch
      feeds.each(&:fetch)
      @last_fetched = Time.now
      save
    end

    def new_entries(&block)
      feeds.each do |f| 
        f.new_entries.each do |a| 
          message = <<~EOS
          #{a[:title]}
          #{a[:url]}
          EOS
          block.call(message)
        end
      end
    end

    def entries_since(from, &block)
      from_dt = DateTime.parse(from.to_s)
      feeds.each do |f| 
        f.entries.each do |a| 
          last_updated = DateTime.parse(a[:last_updated].to_s)
          if last_updated > from_dt
            message = <<~EOS
            #{a[:title]}
            #{a[:url]}
            EOS
            block.call(message)
          end
        end
      end

    end

    private
    def feed_for(url)
      feeds = Feedbag.find(url)
      feeds.first
    end

    def add(feed)
      feeds.unshift(feed)
    end
  end
end
