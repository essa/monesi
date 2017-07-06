# coding: utf-8

require 'spec_helper'

describe Monesi::FeedManager do
  STATE_FILE_PATH = "/tmp/monesi_state.yml"
  subject do
    Monesi::FeedManager.new(path: STATE_FILE_PATH)
  end

  it "should be initialized" do
    should_not be_nil
  end

  if $WEBMOCK_TEST
    let!(:hatena_index) do
      index = File::open('spec/fixtures/d.hatena.ne.jp/index.html')
      stub_request(:get, "http://d.hatena.ne.jp/essa/")
        .to_return(body: index, headers: { 'Content-Type' => 'text/html; charset=euc-jp' })
    end

    let!(:hatena_rss) do
      rss = File::open('spec/fixtures/d.hatena.ne.jp/rss.xml')
      stub_request(:get, "http://d.hatena.ne.jp/essa/rss")
        .to_return(body: rss, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})
    end

    let!(:qiita_index) do
      index = File::open('spec/fixtures/qiita.com/mastodon.html')
      stub_request(:get, "http://qiita.com/tags/mastodon")
        .to_return(body: index, headers: { 'Content-Type' => 'text/html; charset=euc-jp' })
    end

    let!(:qiita_atom) do
      atom = File::open('spec/fixtures/qiita.com/mastodon_atom.xml')
      stub_request(:get, "http://qiita.com/tags/mastodon/feed")
        .to_return(body: atom, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})
    end
  else
    let!(:hatena_index) { nil }
    let!(:hatena_rss) { nil }
    let!(:qiita_index) { nil }
    let!(:qiita_atom) { nil }
  end

  describe "#subscribe" do
    it "should subscribe a feed from hatena diary url" do

      subject.subscribe("http://d.hatena.ne.jp/essa/")

      expect(hatena_index).to have_been_requested if hatena_index
      expect(hatena_rss).to have_been_requested if hatena_rss
      feed = subject.feeds.first
      expect(feed.title).to eq("アンカテ")
      expect(feed.entries.map { |e| e[:url] }).to include('http://d.hatena.ne.jp/essa/20170619/p1')
    end

    it "should subscribe a feed from qiita" do

      subject.subscribe("http://qiita.com/tags/mastodon")

      expect(qiita_index).to have_been_requested if qiita_index
      expect(qiita_atom).to have_been_requested if qiita_atom
      feed = subject.feeds.first
      expect(feed.title).to eq("mastodonタグが付けられた新着投稿 - Qiita")
      expect(feed.entries.map { |e| e[:url] }).to include('http://qiita.com/magicpot73@github/items/9ae01dd1bce47863235c')

    end

    it "should subscribe two feeds" do

      subject.subscribe("http://d.hatena.ne.jp/essa/")
      subject.subscribe("http://qiita.com/tags/mastodon")

      expect(hatena_index).to have_been_requested if hatena_index
      expect(hatena_rss).to have_been_requested if hatena_rss
      expect(qiita_index).to have_been_requested if qiita_index
      expect(qiita_atom).to have_been_requested if qiita_atom

      expect(subject.feeds.size).to eq(2)
      expect(subject.feeds.map(&:title)).to eq [
                                              "mastodonタグが付けられた新着投稿 - Qiita",
                                              "アンカテ"
                                            ]
    end

    it "should reject non feed url" do
      if $WEBMOCK_TEST
        stub_request(:get, "http://non-existing.host.com/")
                     .to_return(status: 404)
      end

      expect do
        subject.subscribe("http://non-existing.host.com")
      end.to raise_error(RuntimeError)

      expect(subject.feeds.size).to eq(0)
    end

    it "should reject subscribed feed" do

      subject.subscribe("http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(1)

      expect do
        subject.subscribe("http://d.hatena.ne.jp/essa/")
      end.to raise_error(RuntimeError)
      expect(subject.feeds.size).to eq(1)
    end
  end

  describe("#fetch") do
    before do
      subject.subscribe("http://qiita.com/tags/mastodon")
    end

    let(:feed) { subject.feeds.first}

    it "should return empty new_entries" do
      subject.fetch
      expect(feed.new_entries).to be_empty
    end
    
    it "should return updated new_entries" do
      atom = File::open('spec/fixtures/qiita.com/mastodon_atom2.xml')
      stub_request(:get, "http://qiita.com/tags/mastodon/feed")
        .to_return(body: atom, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})
      subject.fetch
      expect(feed.new_entries.size).to eq(1)
      article = feed.new_entries.first
      expect(article[:url]).to eq('http://qiita.com/magicpot73@github/items/c3069520050df9d27226')
    end

  end

  describe("#unsubscribe") do
    it "should unsubscribe feed" do

      subject.subscribe("http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(1)

      subject.unsubscribe("http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(0)
    end

    it "should rotate feeds" do

      subject.subscribe("http://d.hatena.ne.jp/essa/")
      subject.subscribe("http://qiita.com/tags/mastodon")
      expect(subject.feeds.size).to eq(2)

      subject.unsubscribe("http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(1)
      expect(subject.feeds.first.feed_url).to eq("http://qiita.com/tags/mastodon/feed")
    end
  end

  describe("#save/load") do
    it "should save/load feeds" do
      subject.subscribe("http://d.hatena.ne.jp/essa/")
      subject.subscribe("http://qiita.com/tags/mastodon")
      expect(subject.feeds.size).to eq(2)

      subject.save
      manager = Monesi::FeedManager.new(path: STATE_FILE_PATH)
      manager.load

      expect(manager.feeds.size).to eq(2)
      expect(manager.feeds.map(&:title)).to eq [
                                              "mastodonタグが付けられた新着投稿 - Qiita",
                                              "アンカテ"
                                            ]

    end
  end
end

