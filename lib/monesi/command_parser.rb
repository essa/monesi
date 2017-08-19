
require 'parslet'

module Monesi
  class CommandParser
    class Parser < Parslet::Parser
      # Single character rules
      rule(:lparen)     { str('(') >> space? }
      rule(:rparen)     { str(')') >> space? }
      rule(:comma)      { str(',') >> space? }

      rule(:space)      { match('\s').repeat(1) }
      rule(:space?)     { space.maybe }

      # Things
      rule(:integer)    { match('[0-9]').repeat(1).as(:int) >> space? }
      rule(:identifier) { match['a-z'].repeat(1) }
      rule(:url) { match['\S'].repeat(1) }
      rule(:mention)    { str('@') >> identifier}

      rule(:simple_command) {
        (
          str("list") |
          str("fetch") |
          str("version") |
          str("end") |
          str("quit") |
          str("help")
        ).as(:command)
      }

      rule(:feed_command) {
        (
          str('show_articles') | 
          str('show_meta') | 
          str('unsubscribe')
        ).as(:command) >> space >>
          identifier.as(:feed_id)
      }

      rule(:with) {
        str('with')
      }

      rule(:subscribe) {
        str('subscribe').as(:subscribe) >> space >>
          url.as(:url) >> space >>
          str("as") >> space >>
          identifier.as(:feed_id) >> space? >>
          with.maybe
      }

      rule(:command) {
        space? >> mention.maybe >> space? >>
          ( subscribe | feed_command | simple_command ) >>
          space?
      }

      root :command
    end

    class Transform < Parslet::Transform
      rule(:command => simple(:command)) { [command.to_s.intern] }
      rule(:command => simple(:command), :feed_id => simple(:feed_id)) { [ command.to_s.intern, feed_id]}
      rule(:subscribe => simple(:subscribe), :feed_id => simple(:feed_id), :url => simple(:url)) { [:subscribe, url, feed_id]}
    end

    attr_reader :feed_manager
    def initialize(options)
      @feed_manager = options[:feed_manager]
      @debug = options[:debug]
    end

    def parse_command(text)
      parser = Parser.new
      transform = Transform.new
      transform.apply(parser.parse(text))
    end

    def parse(text, &block)
      cmd, *args = *parse_command(text)
      case cmd
      when :unsubscribe
        feed_id = args.first.to_s.intern
        feed_manager.unsubscribe(feed_id)
        ans = "unsubscribed #{feed_id}"
        block.call(ans)
      when :subscribe
        url = args[0]
        feed_id = args[1].to_s.intern
        options_text = args[2].to_s
        options = parse_options(options_text)
        feed_manager.subscribe(feed_id, url, options)
        ans = "subscribed #{url} as #{feed_id}"
        block.call(ans)
      when /list/
        ans = "\n"
        feed_manager.feeds.map do |feed_id, f| 
          options = feed_manager.feed_option_for(feed_id)
          l = "#{feed_id} #{f.title.to_s.force_encoding('UTF-8')} #{f.feed_url} #{options}\n".force_encoding("UTF-8")
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
      when /show_articles\s+(\S+)/
        feed_manager.show_articles($1.intern, &block)
      when /show_meta\s+(\S+)/
        feed_manager.show_meta($1, &block)
      when /help/
        block.call help_text
      when /version/
        block.call "Monesi: feed reader for Mastodon #{Monesi::Version}"
      when /end|quit/
        raise EOFError
      else
        # just ignore
      end
    rescue EOFError
      raise
    rescue Parslet::ParseFailed
      block.call help_text
    rescue
      block.call("something wrong with '#{text}' #{$!}")
      block.call($@) if @debug
    end 

    def parse__(text, &block)
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
        feed_manager.feeds.map do |feed_id, f| 
          options = feed_manager.feed_option_for(feed_id)
          l = "#{feed_id} #{f.title.to_s.force_encoding('UTF-8')} #{f.feed_url} #{options}\n".force_encoding("UTF-8")
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
      when /show_articles\s+(\S+)/
        feed_manager.show_articles($1.intern, &block)
      when /show_meta\s+(\S+)/
        feed_manager.show_meta($1, &block)
      when /help/
        block.call help_text
      when /version/
        block.call "Monesi: feed reader for Mastodon #{Monesi::Version}"
      when /end|quit/
        raise EOFError
      else
        # just ignore
      end
    rescue EOFError
      raise
    rescue
      block.call("something wrong with '#{text}' #{$!}")
      block.call($@) if @debug
    end 


    def help_text
      <<~EOS
      commands for monesi
        subscribe <feed id> <feed url> [options]
        unsubscribe <feed id>
        fetch
        list
        help
        show_articles feed_id
      subscribe options
        meta_filter(<name>=<value>)
        meta_filter(<name>=~/<value>/)
        tag(<tag name>)
      EOS
    end

    private

    def parse_options(text)
      options = {}
      if text =~ /meta_filter\(([\w\:]+)=~\/([^)]*?)\/\)/
        options.merge! meta_filter: { $1 => Regexp.new($2) }
      elsif text =~ /meta_filter\(([\w\:]+)=([^)]*?)\)/
        options.merge! meta_filter: { $1 => $2 }
      end
      if text =~ /feed_author_filter\(([^)]*?)\)/
        options.merge! feed_author_filter: $1
      end
      if text =~ /tag\((.*)\)/
        options.merge! tag: $1
      end
      options
    end
  end
end
