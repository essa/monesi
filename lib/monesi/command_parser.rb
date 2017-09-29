
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
      rule(:identifier) { match['^\s:()=,'].repeat(1) } # to allow Japanese characters
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
          str('unsubscribe')
        ).as(:command) >> space >>
          identifier.as(:feed_id)
      }

      rule(:key) { match['^=~()'].repeat }
      rule(:val) { match['^=~()'].repeat }
      rule(:operator) { str("=~")  | str("=") }

      rule(:condition) {
        key.as(:key) >>
          operator.as(:op) >>
          val.as(:val) 
      }

      rule(:tags) {
        (identifier.as(:tag) >> comma.maybe).repeat
      }

      rule(:subscribe_option) {
        (str("meta_filter") >> str("(") >> condition >> str(")")).as(:meta_filter) |
          (str("feed_author_filter") >> str("(") >> val.as(:author) >> str(")")).as(:feed_author_filter) |
          (str("tag") >> str("(") >> tags.as(:tags) >> str(")")).as(:tag) |
          str("redirect_url").as(:redirect_url)
      }

      rule(:subscribe_options) {
        (subscribe_option >> space?).repeat
      }

      rule(:with) {{
                   }
        str('with') >> space >> subscribe_options
      }

      rule(:subscribe) {
        str('subscribe').as(:subscribe) >> space >>
          url.as(:url) >> space >>
          str("as") >> space >>
          identifier.as(:feed_id) >> space? >>
          with.maybe.as(:with)
      }

      rule(:show_meta) {
        str('show_meta').as(:show_meta) >> space >>
          url.as(:url) 
      }

      rule(:command) {
        space? >> mention.maybe >> space? >>
          ( subscribe | show_meta | feed_command | simple_command ) >>
          space?
      }

      root :command
    end

    class Transform < Parslet::Transform
      rule(:command => simple(:command)) { [command.to_s.intern] }
      rule(:command => simple(:command), :feed_id => simple(:feed_id)) { [ command.to_s.intern, feed_id]}
      rule(:subscribe => simple(:subscribe), :feed_id => simple(:feed_id), :url => simple(:url)) { [:subscribe, url, feed_id]}
      rule(:subscribe => simple(:subscribe), :feed_id => simple(:feed_id), :url => simple(:url), :with => subtree(:with)) do
        with_hash = (with or []).inject({}) do |h, hh| 
          h.merge(hh)
        end
        [:subscribe, url.to_s, feed_id.to_s, with_hash]
      end
      rule(:meta_filter=>subtree(:options)) do
        {
          meta_filter: {
            key: options[:key].to_s,
            op: options[:op].to_s,
            val: options[:val].to_s
          }
        }
      end
      rule(:redirect_url=>subtree(:options)) do
        { :redirect_url => true}
      end
      rule(:author=>simple(:author)) { author.to_s }
      rule(:tags=>subtree(:tags)) do
        tags.map do |t| 
          t[:tag].to_s
        end
      end

      rule(:show_meta => simple(:command), :url => simple(:url)) do
        [:show_meta, url.to_s]
      end
    end

    attr_reader :feed_manager
    def initialize(options)
      @feed_manager = options[:feed_manager]
      @debug = options[:debug]
    end

    def parse_command(text)
      parser = Parser.new
      transform = Transform.new
      t = parser.parse(text)
      transform.apply(t)
    end

    def parse(text, &block)
      cmd, *args = *parse_command(text)
      # p cmd,args
      case cmd
      when :unsubscribe
        feed_id = args.first.to_s.intern
        feed_manager.unsubscribe(feed_id)
        ans = "unsubscribed #{feed_id}"
        block.call(ans)
      when :subscribe
        url = args[0]
        feed_id = args[1].to_s.intern
        options = args[2]
        feed_manager.subscribe(feed_id, url, options)
        ans = "subscribed #{url} as ##{feed_id}"
        block.call(ans)
      when :list
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
      when :fetch
        feed_manager.fetch
        feed_manager.new_entries do |msg| 
          block.call(msg)
        end
        block.call('fetched')
      when :show_articles
        feed_manager.show_articles(args.first.to_s.intern, &block)
      when :show_meta
        feed_manager.show_meta(args.first.to_s, &block)
      when :help
        block.call help_text
      when :version
        block.call "Monesi: feed reader for Mastodon #{Monesi::Version}"
      when :end, :quit
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

  end
end
