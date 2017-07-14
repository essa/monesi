
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
      when /subscribe\s+(\S+)(?:\s+with\s+(.*))?/
        url = $1
        options_text = $2
        options = parse_options(options_text)
        feed_manager.subscribe(url, options)
        ans = "subscribed #{url}"
        block.call(ans)
      when /list/
        ans = "\n"
        feed_manager.feeds.map do |f| 
          options = feed_manager.feed_option_for(f)
          l = "#{f.title} #{f.feed_url} #{options}\n".force_encoding("UTF-8")
          if (ans + l).size > 400
            block.call(ans)
            ans = "\n" + l
          else
            ans = ans + l
          end
        end
        block.call(ans)
      when /fetch/
        feed_manager.fetch
        feed_manager.new_entries do |msg| 
          block.call(msg)
        end
        block.call('fetched')
      else
        block.call("Sorry, I can't understand '#{text}'\n" + help_text)
      end
    rescue
      block.call("something wrong with '#{text}' #{$!}")
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

    private

    def parse_options(text)
      options = {}
      if text =~ /meta_filter\(([\w\:]+)=([^)]*)\)/
        options.merge! meta_filter: { $1 => $2 }
      end
      if text =~ /tag\((.*)\)/
        options.merge! tag: $1
      end
      options
    end
  end
end
