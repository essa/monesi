
module Monesi
  class CommandParser
    attr_reader :feed_manager
    def initialize(options)
      @feed_manager = options[:feed_manager]
    end

    def parse(text, &block)
      case text
      when /unsubscribe\s+(\S+)/
        feed_id = $1.to_s.intern
        feed_manager.unsubscribe(feed_id)
        ans = "unsubscribed #{feed_id}"
        block.call(ans)
      when /subscribe\s+(\S+)\s+as\s+(\S+)(?:\s+with\s+(.*))?/
        url = $1
        feed_id = $2.to_s.intern
        options_text = $3
        options = parse_options(options_text)
        feed_manager.subscribe(feed_id, url, options)
        ans = "subscribed #{url} as #{feed_id}"
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
        # just ignore
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
      if text =~ /meta_filter\(([\w\:]+)=~\/([^)]*)\/\)/
        options.merge! meta_filter: { $1 => Regexp.new($2) }
      elsif text =~ /meta_filter\(([\w\:]+)=([^)]*)\)/
        options.merge! meta_filter: { $1 => $2 }
      end
      if text =~ /tag\((.*)\)/
        options.merge! tag: $1
      end
      options
    end
  end
end
