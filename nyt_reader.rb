#!/usr/bin/env ruby

require 'open-uri'

# Gems
require 'nokogiri'
require 'gepub'
require 'pry'

URL = 'https://cn.nytimes.com/async/mostviewed/all/?lang=zh-hans'

def main
  # Download articles
  articles = load_web_articles(URL) # load_dummy_articles 
  puts "#{articles.count} articles downloaded."

  # Generate .epub files
  articles.map! {|a| generate_book(a)}
end

def load_dummy_articles
  [{
    title: "Hello Title",
    description: "Some cool stuff happened somewhere",
    photo_url: "https://i2.wp.com/metro.co.uk/wp-content/uploads/2017/07/187144066.jpg",
    content: "CONTENT!!!! Helllllllllooooooooooooooooooooooooooooooooooo CONTENT!!!!"
  }]
end

def load_web_articles(url)
  json = JSON.parse(open(url) {|f| f.read})
  articles = get_articles(json).uniq {|a| a[:title]}
  articles = articles.select {|a| !a[:content].to_s.strip.empty?}
end

def get_articles(json)
  dailies = json['list']['daily'].map {|i| build_article(i)}
  weeklies = json['list']['weekly'].map {|i| build_article(i)}
  dailies + weeklies
end

def build_article(raw_article)
  url = raw_article['url']
  headline = raw_article['headline']
  short_headline = raw_article['short_headline']
  summary = raw_article['summary']
  photo_url = raw_article['photo']['url']
  content = get_article_content(url)

  article = {
    title: headline,
    description: summary,
    photo_url: photo_url,
    content: content
  }
  File.write("/tmp/#{headline}.json", article.to_json)

  article
end

def get_article_content(url)
  # puts url
  nokogiri = Nokogiri::HTML(open(url))
  paragraphs = nokogiri.css('.article-partial .article-paragraph')
  paragraphs.reduce('') {|sum, p| sum += "\n#{p.content}"}
end

def generate_book(article)
  book = GEPUB::Book.new
  book.primary_identifier('#YOLO')
  book.language = 'zh'

  # Title
  book.add_title(article[:title], 
                 title_type: GEPUB::TITLE_TYPE::MAIN,
                 lang: 'zh',
                 file_as: article[:title],
                 display_seq: 1,
                 alternates: {
                   'en' => 'English title!',
                   'zh' => article[:title]
                 })

  # Setup cover image
  cover_filename = "/tmp/#{article[:title]}_cover.jpg"
  open(article[:photo_url]) do |image|
    File.open(cover_filename, "wb") {|file| file.write(image.read)}
  end

  File.open(cover_filename) do |io|
    book.add_item('img/cover.jpg', content: io).cover_image
  end

  # Contents
  book.ordered {
    book.add_item('text/cover.xhtml',
                  content: StringIO.new(<<-COVER)).landmark(type: 'cover', title: 'cover page')
                <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                  <title>Cover Page</title>
                </head>
                <body>
                <h1>#{article[:title]}</h1>
                <h2>#{article[:description]}</h2>
                <img src="../img/cover.jpg" />
                </body></html>
  COVER
  book.add_item('text/chap1.xhtml').add_content(StringIO.new(<<-CHAP_ONE)).toc_text('Chapter 1').landmark(type: 'bodymatter', title: '本文')
  <html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>c1</title></head>
  <body><p>#{article[:content]}</p></body></html>
  CHAP_ONE
  }

  book.generate_epub("/tmp/#{article[:title]}.epub")
end

# START
main
