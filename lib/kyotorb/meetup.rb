# coding: utf-8

require 'fileutils'
require 'open-uri'
require 'date'
require 'uri'
require 'erb'
require 'nokogiri'

module Kyotorb
  class Meetup
    WIKI_REPOSITORY    = 'https://github.com/kyotorb/meetup.wiki.git'
    WIKI_TEMPLATE_PATH = File.expand_path('templates/meetup_wiki.md.erb', File.dirname(__FILE__))

    attr_reader :mail_uri

    def initialize(uri)
      @mail_uri = uri
      @numbering, @date = parse_mail(@mail_uri)
    end

    def numbering
      @numbering || 0
    end

    def date
      @date || Date.today
    end

    def generate(type)
      case type
      when :wiki
        generate_wiki!
      end
    end

    def generate_wiki!
      initialize_or_update_wiki
      copy_template
      update_histories
      publish_wiki
    end

    def initialize_or_update_wiki
      if File.exist?(wiki_dir)
        FileUtils.cd(wiki_dir) do
          git.stash do
            git.pull
          end
        end
      else
        git.clone WIKI_REPOSITORY, wiki_dir
      end
    end

    def copy_template
      template = ERB.new(File.read(WIKI_TEMPLATE_PATH)).result(binding)
      file_name = File.join(wiki_dir, wiki_file_name)
      return if File.exist?(file_name)
      File.open(file_name, 'wb:utf-8') do |io|
        io.print template
      end
    end

    def update_histories
      home_file_path = File.join(wiki_dir, 'Home.md')
      body = ''
      flag = false
      File.readlines(home_file_path).each do |line|
        if !flag && /\A\* / =~ line
          body << "* #{history_link}\n"
          flag = true
        end
        body << line
      end
      File.write(home_file_path, body)
    end

    def history_link
      "[[#{name}]] - #{wiki_date}"
    end

    def publish_wiki
      raise unless File.exist?(wiki_dir)
      FileUtils.cd(wiki_dir) do
        git.add 'Home.md'
        git.add wiki_file_name
        git.commit "Created next meetup ##{numbering}"
        git.stash do
          git.push
        end
      end
    end

    def wiki_dir
      @wiki_dir ||= File.expand_path('../../../meetup.wiki', File.dirname(__FILE__))
    end

    def wiki_date
      self.date.to_s.gsub('-', '/')
    end

    def wiki_file_name
      "#{name.gsub(' ', '-')}.md"
    end

    def name
      "第#{numbering_kanji}回 Meetup"
    end

    def git
      @git = Git.new
    end

    private
    def parse_mail(url)
      doc = Nokogiri(open(url))
      numbering, date = *doc.title.match(/#(\d+) \((.*)\)/)[1, 2]
      [numbering, Date.parse(date)]
    end

    KANSUJI = %w[零 一 二 三 四 五 六 七 八 九]
    DIGITS  = ['', '十','百'] # MEMO: support until 百
    def numbering_kanji
      num_s = self.numbering.to_s
      num_s.reverse.scan(/\d/).map.with_index {|num, digit|
        num_kanji = ''
        if digit < 1 || num.to_i > 1
          num_kanji << KANSUJI[num.to_i]
        end
        num_kanji << DIGITS[digit]
        num_kanji
      }.reverse.join
    end
  end
end

