
module Monesi
  class CommandParser
    attr_reader :feed_manager
    def initialize(options)
      @feed_manager = options[:feed_manager]
    end

    def parse(text, &block)
      case text
      when /unsubscribe\s+(\S+)/
        url = $1
        feed_manager.unsubscribe(url)
        ans = "unsubscribed #{url}"
        block.call(ans)
      when /subscribe\s+(\S+)/
        url = $1
        feed_manager.subscribe(url)
        ans = "subscribed #{url}"
        block.call(ans)
      when /list/
        ans = feed_manager.feeds.map do |f| 
          "#{f.title} #{f.feed_url}".force_encoding("UTF-8")
        end.join("\n")
        block.call(ans)
      when /fetch/
        feed_manager.fetch
        block.call('fetched')
      when /entries since (\S+)/
        feed_manager.entries_since($1) do |msg| 
          block.call(msg)
        end
      else
        block.call("Sorry, I can't understand\n" + help_text)
      end
    rescue
      block.call($!.to_s)
      raise
    end 

    def help_text
      <<~EOS
      commands for monesi
        subscribe <feed url>
        unsubscribe <feed url>
        fetch
        list
      EOS
    end
  end
end
