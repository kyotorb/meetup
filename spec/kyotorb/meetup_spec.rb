# coding: utf-8

require_relative '../spec_helper'

module Kyotorb
  class DummyGit < Git
    attr_reader :dummy_io

    def initialize
      @dummy_io = StringIO.new
    end
    def rewind
      self.dummy_io.rewind
    end
    def gets
      self.dummy_io.gets
    end
    def execute(*args)
      self.dummy_io.puts "git #{args.join(' ')}"
    end
  end

  describe Meetup do
    let(:dummy_mail_url) { File.expand_path('mail.html', File.dirname(__FILE__)) }
    let(:wiki_dir) { File.expand_path('meetup.wiki', File.dirname(__FILE__)) }

    describe '#generate_wiki' do
      let(:meetup) { Meetup.new(dummy_mail_url) }
      before do
        meetup.stub!(:wiki_dir => wiki_dir) 
        meetup.should_receive(:initialize_or_update_wiki) do
          FileUtils.mkdir_p(wiki_dir)
        end
        meetup.should_receive(:publish_wiki)
        meetup.generate_wiki!
      end
      after do
        FileUtils.remove_entry_secure(wiki_dir, true)
      end
      it 'Wikiのリポジトリが作られていること' do
        expect(File.exist?(wiki_dir)).to be_true
      end
      it 'テンプレートが生成されていること' do
        name = File.join(wiki_dir, meetup.wiki_file_name)
        expect(File.exist?(name)).to be_true
      end
      it 'テンプレートの中身が適切であること' do
        name = File.join(wiki_dir, meetup.wiki_file_name)
        body = File.read(name)
        expect(body).to match(/#{meetup.wiki_date}/)
        expect(body).to match(/#{meetup.mail_uri}/)
      end
    end

    describe '#initialize_or_update_wiki' do
      let(:meetup) { Meetup.new(dummy_mail_url) }
      before do
        meetup.stub!(:wiki_dir => wiki_dir)
        @dummy_git = DummyGit.new
        meetup.stub!(:git => @dummy_git)
      end
      after do
        FileUtils.remove_entry_secure(wiki_dir, true)
      end
      context 'まだディレクトリがないとき' do
        subject { @dummy_git }
        before do
          meetup.initialize_or_update_wiki
          subject.rewind
        end
        it 'リポジトリがcloneされること' do
          expect(subject.gets).to match(/git clone #{Meetup::WIKI_REPOSITORY} #{wiki_dir}/)
        end
      end
      context 'ディレクトリが存在しているとき' do
        subject { @dummy_git }
        before do
          FileUtils.mkdir_p(wiki_dir)
          meetup.initialize_or_update_wiki
          @dummy_git.rewind
        end
        it 'リポジトリがpullされること' do
          expect(subject.gets).to match(/git stash save/)
          expect(subject.gets).to match(/git pull/)
          expect(subject.gets).to match(/git stash pop/)
        end
      end
    end

    describe '#publish_wiki' do
      let(:meetup) { Meetup.new(dummy_mail_url) }
      before do
        meetup.stub!(:wiki_dir => wiki_dir)
        @dummy_git = DummyGit.new
        meetup.stub!(:git => @dummy_git)
      end
      context 'ディレクトリがあるとき' do
        before do
          FileUtils.mkdir_p(wiki_dir)
          meetup.publish_wiki
          @dummy_git.rewind
        end
        subject { @dummy_git }
        it 'リポジトリがpushされること' do
          expect(subject.gets).to match(/git stash save/)
          expect(subject.gets).to match(/git add #{meetup.wiki_file_name}/)
          expect(subject.gets).to match(/git commit -m 'Created next meetup ##{meetup.numbering}'/)
          expect(subject.gets).to match(/git push/)
          expect(subject.gets).to match(/git stash pop/)
        end
      end
      context 'ディレクトリが存在していないとき' do
        before do
          FileUtils.remove_entry_secure(wiki_dir, true)
        end
        it { expect { meetup.publish_wiki }.to raise_error }
      end
    end

    describe '#name' do
      let(:meetup) { Meetup.new(dummy_mail_url) }
      [
        [1, '一'],
        [2, '二'],
        [3, '三'],
        [15, '十五'],
        [27, '二十七']
      ].each do |num, kanji|
        context "#{kanji}回目のとき" do
          before do
            meetup.stub!(:numbering => num)
          end
          subject { meetup }
          it { expect(subject.name).to eq("第#{kanji}回 Meetup") }
        end
      end
    end
  end
end

