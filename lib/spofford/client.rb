require 'spofford/client/version'
require 'spofford/client/config'
require 'spofford/client/packager'
require 'rest-client'
require 'mimemagic'
require 'socket'

module Spofford
  module Client


    def self.detect_content_type(filename)
      content_type = MimeMagic.by_path(filename)
      if content_type.nil?
        mt = MimeMagic.by_magic(File.open(filename))
        content_type = mt unless mt.nil?
      end
      content_type.nil? ? 'application/json' : content_type.type
    end


      def self.check_content_type(type)
        raise "Content type '#{type}' is not supported with Spofford" unless ['application/json', 'application/zip'].include?(type)
        true
      end


      def self.create(options={})
        return DefaultClient.new(options)
      end

      class DefaultClient

        def initialize(options={})
          @config = options || Spofford::Config.get
        end

      def send(filename)
        raise "File #{filename} not found" unless File.exist?(filename)
          url = @config[:ingest_url] || "#{@config[:base_url]}/ingest/#{@config[:owner]}"
          type = Spofford::Client.detect_content_type(filename)
          Spofford::Client.check_content_type(type)
          RestClient::Request.execute(
            :method => :post,
            :url => url,
            :body => File.open(filename, 'rb'),
            :headers => { 'Content-Type' => type },
            :accept => :json
          )
      end
    end
  end
end
