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

    let!(:itmedia_atom) do
      atom = File::open('spec/fixtures/rss.rssad.jp/news_bursts.xml')
      stub_request(:get, "http://rss.rssad.jp/rss/itmnews/2.0/news_bursts.xml")
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

      subject.subscribe('uncate', "http://d.hatena.ne.jp/essa/")

      expect(hatena_index).to have_been_requested if hatena_index
      expect(hatena_rss).to have_been_requested if hatena_rss
      feed = subject.feeds[:uncate]
      expect(feed.title).to eq("アンカテ")
      expect(feed.entries.map { |e| e[:url] }).to include('http://d.hatena.ne.jp/essa/20170619/p1')
    end

    it "should subscribe a feed from qiita" do

      subject.subscribe(:qiita, "http://qiita.com/tags/mastodon")

      expect(qiita_index).to have_been_requested if qiita_index
      expect(qiita_atom).to have_been_requested if qiita_atom
      feed = subject.feeds[:qiita]
      expect(feed.title).to eq("mastodonタグが付けられた新着投稿 - Qiita")
      expect(feed.entries.map { |e| e[:url] }).to include('http://qiita.com/magicpot73@github/items/9ae01dd1bce47863235c')

    end

    it "should subscribe two feeds" do

      subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa/")
      subject.subscribe(:qiita, "http://qiita.com/tags/mastodon")

      expect(hatena_index).to have_been_requested if hatena_index
      expect(hatena_rss).to have_been_requested if hatena_rss
      expect(qiita_index).to have_been_requested if qiita_index
      expect(qiita_atom).to have_been_requested if qiita_atom

      expect(subject.feeds.size).to eq(2)
      expect(subject.feeds.map{ |_, f| f.title }).to eq [
                                              "アンカテ",
                                              "mastodonタグが付けられた新着投稿 - Qiita",
                                            ]
    end

    it "should reject non feed url" do
      if $WEBMOCK_TEST
        stub_request(:get, "http://non-existing.host.com/")
                     .to_return(status: 404)
      end

      expect do
        subject.subscribe(:error, "http://non-existing.host.com")
      end.to raise_error(RuntimeError)

      expect(subject.feeds.size).to eq(0)
    end

    it "should reject subscribed feed" do

      subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(1)

      expect do
        subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa_xxxx/")
      end.to raise_error(RuntimeError)
      expect(subject.feeds.size).to eq(1)

      # should accept same feed with different id
      subject.subscribe(:uncate2, "http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(2)
    end
  end

  describe("#fetch") do
    before do
      subject.subscribe(:qiita, "http://qiita.com/tags/mastodon")
    end

    let(:feed) { subject.feeds[:qiita] }

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

  describe("#filter") do
    before do
      subject.subscribe(:mastodon, "http://rss.rssad.jp/rss/itmnews/2.0/news_bursts.xml",
                        meta_filter: {'itmid:series'=> 'マストドンつまみ食い日記'} )
    end
    it "should pass all entry without options" do
      article_url ='http://rss.rssad.jp/rss/artclk/XXtgw_wVjwMW/9f85c188d441f0dfaeb38b13067cc9ed?ul=dFXxPH_nlvvejbi.pBVaGQ.GWRexPETyBzUkKBlyRM5f36fvCkTox6TchXHdzU6el7Ykc1bl39Q4j7zFDanCYhZLw0OQiphOeVtcIlf8ehXkhzyEJFuFpBx7U1DemKxW.e6uNQs'

      # matched article
      article = File::open('spec/fixtures/itmedia.co.jp/news051.html')
      stub_request(:get, article_url)
        .to_return(body: article, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})
      r = subject.filter?(article_url, :mastodon)
      expect(r).to be_falsy

      # unmatched article
      article = File::open('spec/fixtures/itmedia.co.jp/news052.html')
      stub_request(:get, article_url)
        .to_return(body: article, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})
      r = subject.filter?(article_url, :mastodon)
      expect(r).to be_truthy
    end

    it "should match with regexp" do
      subject.subscribe(:watch, "http://d.hatena.ne.jp/essa/", meta_filter: { "og:url" => /yajiuma/ })
      article_url = "http://xxxx.com/12345"

      html = '<head><meta property="og:url" content="http://internet.watch.impress.co.jp/docs/yaji/1049067.html"><meta property="og:title" content="【やじうまWatch】現在開発中、ディープラーニングによる2ちゃんライクなアスキーアートの生成技術が評判"></head>'
      stub_request(:get, article_url)
        .to_return(body: html, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})

      r = subject.filter?(article_url, :watch)
      expect(r).to be_truthy

      html = '<head><meta property="og:url" content="http://internet.watch.impress.co.jp/docs/yajiuma/1049067.html"><meta property="og:title" content="【やじうまWatch】現在開発中、ディープラーニングによる2ちゃんライクなアスキーアートの生成技術が評判"></head>'
      stub_request(:get, article_url)
        .to_return(body: html, headers: { 'Content-Type' => 'application/xml; charset=utf-8'})

      r = subject.filter?(article_url, :watch)
      expect(r).to be_falsy
    end
  end

  describe("#unsubscribe") do
    it "should unsubscribe feed" do

      subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa/")
      expect(subject.feeds.size).to eq(1)

      subject.unsubscribe(:uncate)
      expect(subject.feeds.size).to eq(0)
    end

    it "should rotate feeds" do

      subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa/")
      subject.subscribe(:qiita, "http://qiita.com/tags/mastodon")
      expect(subject.feeds.size).to eq(2)

      subject.unsubscribe(:uncate)
      expect(subject.feeds.size).to eq(1)
      expect(subject.feeds.first[1].feed_url).to eq("http://qiita.com/tags/mastodon/feed")
    end
  end

  describe("#save/load") do
    it "should save/load feeds" do
      subject.subscribe(:uncate, "http://d.hatena.ne.jp/essa/")
      subject.subscribe(:qiita, "http://qiita.com/tags/mastodon")
      expect(subject.feeds.size).to eq(2)

      subject.save
      manager = Monesi::FeedManager.new(path: STATE_FILE_PATH)
      manager.load

      expect(manager.feeds.size).to eq(2)
      expect(manager.feeds.map{ |_, f| f.title }).to eq [
                                              "アンカテ",
                                              "mastodonタグが付けられた新着投稿 - Qiita",
                                            ]

    end
  end
end

