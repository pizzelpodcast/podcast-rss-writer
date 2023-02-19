# frozen_string_literal: true

require 'dry-struct'
require 'nokogiri'

module PodcastRss
  module Types
    include Dry.Types()

    ArrayOrString = Types::Array.of(Types::Coercible::String) | Types::Coercible::String
  end

  class Episode < Dry::Struct
    attribute :title,           Types::Coercible::String
    attribute :link,            Types::Coercible::String.optional.default(nil)
    attribute :guid,            Types::Coercible::String.optional.default(nil)
    attribute :pub_date,        Types::Params::Date.optional.default(nil)
    attribute :description,     Types::Coercible::String.optional.default(nil)
    attribute :itunes_duration, Types::Coercible::Integer
    attribute :itunes_explicit, Types::Bool
    #attribute :itunes_author,   Types::Coercible::String.optional
    #attribute :itunes_subtitle, Types::Coercible::String
    #attribute :itunes_image,    Types::Coercible::String
  end

  class Channel < Dry::Struct
    attribute :title,               Types::Coercible::String
    attribute :link,                Types::Coercible::String.optional.default(nil)
    attribute :description,         Types::Coercible::String
    attribute :language,            Types::Coercible::String
    attribute :copyright,           Types::Coercible::String.optional.default(nil)
    attribute :itunes_author,       Types::Coercible::String.optional.default(nil)
    attribute :itunes_image,        Types::Coercible::String
    attribute :itunes_category,     Types::Array.of(Types::ArrayOrString) | Types::ArrayOrString
    attribute :itunes_explicit,     Types::Bool
    attribute :itunes_type,         Types::Coercible::String.enum('episodic', 'serial').optional.default(nil)
    attribute :itunes_owner,        Types::Coercible::String.optional.default(nil)
    attribute :itunes_new_feed_url, Types::Coercible::String.optional.default(nil)
    attribute :itunes_block,        Types::Bool.optional.default(false)
    attribute :itunes_complete,     Types::Bool.optional.default(false)
    attribute :episodes,            Types::Array.of(Types::Constructor(Episode))
  end

  Podcast = Channel

  class Writer
    RSS_ATTRIBUTES = {
      'version'          => '2.0',
      'xmlns:itunes'     => 'http://www.itunes.com/dtds/podcast-1.0.dtd',
      'xmlns:googleplay' => 'http://www.google.com/schemas/play-podcasts/1.0'
    }.freeze

    attr_reader :podcast

    def initialize(podcast)
      @podcast = podcast
    end

    def write
      rss.to_xml
    end

    private

    def rss
      @rss ||= Nokogiri::XML::Builder.new do |xml|
        xml.rss(RSS_ATTRIBUTES) do
          xml.channel do
            xml.title       podcast.title
            xml.link        podcast.link
            xml.description podcast.description
            xml.language    podcast.language
            xml.copyright   podcast.copyright

            xml['itunes'].author   podcast.itunes_author
            xml['itunes'].type     podcast.itunes_type if podcast.itunes_type
            xml['itunes'].image    href: podcast.itunes_image
            xml['itunes'].explicit podcast.itunes_explicit
            xml['itunes'].block    'Yes' if podcast.itunes_block
            xml['itunes'].complete 'Yes' if podcast.itunes_complete

            [*podcast.itunes_category].each do |category|
              xml['itunes'].category(text: category.respond_to?(:first) ? category.first : category) do
                if category.respond_to?(:each) && category.length > 1
                  xml['itunes'].category text: category.last
                end
              end
            end

            if podcast.itunes_owner
              mailbox = parse_mailbox(podcast.itunes_owner)
              xml['itunes'].owner do
                xml['itunes'].email mailbox.address
                xml['itunes'].name  mailbox.display_name
              end
            end

            if podcast.itunes_new_feed_url
              xml['itunes'].send :'new-feed-url', podcast.itunes_new_feed_url
            end

            podcast.episodes.each do |episode|
              xml.item do
                xml.title       episode.title
                xml.link        episode.link
                xml.guid        episode.guid
                xml.description { xml.cdata episode.description }
              end
            end
          end
        end
      end
    end

    def parse_mailbox(str)
      require 'mail'
      Mail::Address.new(str)
    end
  end
end
