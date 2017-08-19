# coding: utf-8

require 'spec_helper'
describe Monesi::CommandParser do
  let(:feed_manager) { double("feed_manager") }

  subject do
    Monesi::CommandParser.new(feed_manager: feed_manager, debug: false)
  end

  it "should be initialized" do
    should_not be_nil
  end

  describe "#parse_command" do
    it "should parse help command" do
      r = subject.parse_command("help")
      expect(r).to eq [:help]
    end

    it "should parse fetch command" do
      r = subject.parse_command("fetch")
      expect(r).to eq [:fetch]
    end

    it "should parse list command" do
      r = subject.parse_command("@monesi list   ")
      expect(r).to eq [:list]
    end

    it "should parse unsubscribe command" do
      r = subject.parse_command("unsubscribe uncate")
      expect(r).to eq [:unsubscribe, 'uncate']
    end

    it "should parse subscribe command" do
      r = subject.parse_command(" @monesi subscribe http://d.hatena.ne.jp/essa/ as uncate")
      expect(r).to eq [:subscribe, 'http://d.hatena.ne.jp/essa/', 'uncate']
    end

    it "should parse subscribe command with meta_filter" do
      r subject.parse_command("subscribe http://d.hatena.ne.jp/essa/ as uncate with meta_filter(itmid:series=マストドンつまみ食い日記)") 
      expect(r).to eq [
                     :subscribe,
                     'http://d.hatena.ne.jp/essa/',
                     'uncate',
                     {
                       meta_filter: {'itmid:series'=> 'マストドンつまみ食い日記'} 
                     }
                   ]
    end

    it "should parse show_articles command" do
      r = subject.parse_command(" @monesi show_articles uncate")
      expect(r).to eq [:show_articles, 'uncate']
    end

    it "should parse show_meta command" do
      r = subject.parse_command(" @monesi show_meta uncate")
      expect(r).to eq [:show_meta, 'uncate']
    end
  end

  describe "#subscribe" do
    it "should subsribe a feed for request" do
      expect(feed_manager).to receive(:subscribe).with(:uncate, "http://d.hatena.ne.jp/essa/", {})
      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate") do |ans| 
        expect(ans).to include("subscribed")
      end
    end

    it "should process exception" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:uncate, "http://d.hatena.ne.jp/essa/", {})
                               .and_raise(RuntimeError, "error message xyz")

      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate") do |ans| 
        expect(ans).to include("error message xyz")
      end
    end

    it "should process meta_filter option" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:uncate, "http://d.hatena.ne.jp/essa/", meta_filter: {'itmid:series'=> 'マストドンつまみ食い日記'} )

      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate with meta_filter(itmid:series=マストドンつまみ食い日記)") do |ans| 
        p ans
      end
    end

    it "should process meta_filter option with regexp" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:uncate, "http://d.hatena.ne.jp/essa/", meta_filter: {'og:url'=> /yajiuma/} )

      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate with meta_filter(og:url=~/yajiuma/)") do |ans| 
        p ans
      end
    end

    it "should process feed_author_filter" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:kan_ito, "http://jbpress.ismedia.jp/list/feed/rss/", feed_author_filter: '伊東 乾')

      subject.parse('subscribe http://jbpress.ismedia.jp/list/feed/rss/ as kan_ito with feed_author_filter(伊東 乾)') do |ans|
        p ans
      end
    end

    it "should process tag option" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:uncate, "http://d.hatena.ne.jp/essa/", tag: "blog")

      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate with tag(blog)") do |ans| 
        p ans
      end
    end
  end
  describe "#unsubscribe" do
    it "should unsubsribe a feed for request" do
      expect(feed_manager).to receive(:unsubscribe).with(:uncate)
      subject.parse("unsubscribe uncate") do |ans| 
        expect(ans).to include("unsubscribed")
      end
    end
  end

  describe "#help" do
    it "should answer short help text for unknown command" do
      subject.parse("unknown command") do |ans| 
        expect(ans).to include(subject.help_text)
      end
    end
  end
end

