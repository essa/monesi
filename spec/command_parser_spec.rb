# coding: utf-8

require 'spec_helper'
describe Monesi::CommandParser do
  let(:feed_manager) { double("feed_manager") }

  subject do
    Monesi::CommandParser.new(feed_manager: feed_manager)
  end

  it "should be initialized" do
    should_not be_nil
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

    it "should process meta_filter option" do
      expect(feed_manager).to receive(:subscribe)
                               .with(:uncate, "http://d.hatena.ne.jp/essa/", meta_filter: {'og:url'=> /yajiuma/} )

      subject.parse("subscribe http://d.hatena.ne.jp/essa/ as uncate with meta_filter(og:url=~/yajiuma/)") do |ans| 
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

