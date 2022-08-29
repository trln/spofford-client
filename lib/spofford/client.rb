require 'faraday'
require 'net/http'
require 'mimemagic'
require 'socket'
require 'logger'
require 'uri'
require 'json'
require 'spofford/client/errors'

module Spofford
  # Module containing classes and method for interacting with a Spofford server.
  module Client
    autoload :VERSION, 'spofford/client/version'
    autoload :Config, 'spofford/client/config'
    autoload :Packager, 'spofford/client/packager'
    autoload :Authenticator, 'spofford/client/authenticate'
    autoload :CommandLine, 'spofford/client/commandline'
    autoload :Util, 'spofford/client/util'

    def detect_content_type(filename)
      content_type = MimeMagic.by_path(filename)
      if content_type.nil?
        mt = MimeMagic.by_magic(File.open(filename))
        content_type = mt unless mt.nil?
      end
      content_type.nil? ? 'application/json' : content_type.type
    end

    def accepts_type?(type)
      ['application/json', 'application/zip'].include?(type)
    end

    def self.create(options = {})
      DefaultClient.new(options)
    end

    # Client class that tried to be unsurprising
    class DefaultClient
      include Spofford::Client
      include Spofford::Client::Config
      include Spofford::Client::Util
      include Spofford::Client::Util::ThorLogger

      attr_accessor :config

      def initialize(options = {})
        @config = options[:config] ? load_config(options[:config]) : load_config
        options.delete(:config)
        @config.update(options)
        raise 'URL is not specified' unless @config[:base_url]
        if config[:interactive]
          %i[spofford_account_name authentication_token].each do |key|
            raise "Configuration does not contain required value for #{key}" unless @config[key]
          end
        end
      end

      def debug?
        @debug ||= config[:debug] || false
      end

      def verbose?
        @verbose ||= config[:verbose] || false
      end

      def contents_verified?(filename, type)
        case type
        when 'application/zip'
          !zip_empty?(filename)
        when 'application/json'
          File.exist?(filename) && !File.size?(filename)
        else
          false
        end
      end

      def bail(msg)
        @verbose = true
        say_verbose(msg, :red)
        raise msg
      end

      def response_status(resp)
        "#{resp.message} (#{resp.code})"
      end

      # verify access by performing a 'get' on the ingest URL
      # used for debuggins
      def access_verified?(uri)
        req = Net::HTTP::Get.new(uri)
        req['X-User-Email'] = @config[:spofford_account_name]
        req['X-User-Token'] = @config[:authentication_token]
        warn(req.inspect) if debug?

        resp = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(req)
        end
        if debug?
          warn("\n\n -- Response details follow -- \n\n")
          warn(resp.inspect)
        end
        case resp
        when Net::HTTPRedirection, Net::HTTPForbidden, Net::HTTPNotAuthorized
          shell.say("Authentication to #{uri} failed: #{response_status(resp)}", :red)
          false
        when Net::HTTPOK
          shell.say('GET succeeded, authentication looks good', :green)
          true
        else
          false
        end
      end

      def send(filename)
        bail("File #{filename} not found") unless File.exist?(filename)
        url = @config[:ingest_url] || "#{@config[:base_url]}/ingest/#{@config[:owner]}"
        type = detect_content_type(filename)
        bail("Unsupported content type '#{type}'") unless accepts_type?(type)
        bail("File #{filename} appears to be empty") unless contents_verified?(filename, type)

        return access_verified? if config[:test]

        File.open(filename, 'rb') do |file_stream|
          uri = URI(url)
          req = Net::HTTP::Post.new(url)
          say_verbose("Submitting #{filename} to #{uri} : #{type} as #{config[:spofford_account_name]}")
          req['X-User-Email'] = config[:spofford_account_name]
          req['X-User-Token'] = config[:authentication_token]
          req['Content-Type'] = type
          req['Accept'] = 'application/json'
          req['Content-Length'] = File.size(filename).to_s
          say(req.inspect, :green) if debug?
          req.body_stream = file_stream        
          request_options = {
            use_ssl: uri.scheme == 'https',
            read_timeout: config.fetch(:server_timeout, 120)
          }

          begin
            resp = Net::HTTP.start(uri.hostname, uri.port, request_options) do |http|
              http.set_debug_output($stderr) if debug?
              http.request(req)
            end
          rescue Net::ReadTimeout
            say("Did not get a reponse back from the server within #{config[:server_timeout]} seconds.", :yellow)
            say('Your package may still have uploaded successfully.', :yellow)
            say("You can log in to #{uri.host} interactively to check.", :yellow)
            return false
          rescue StandardError => e
            say("Unexpected error: #{e} -- backtrace", :red)
            say(e.backtrace.join("\t\n"), :red)

            say("Often this indicates that the server didn't respond in time", :yellow)
            say('Your upload, however, may still have succeeded', :yellow)
            say("Please log in to #{uri.host} to check interactively", :yellow)
            return false
          end

          case resp
          when Net::HTTPRequestTimeOut
            say("Request timed out; your package may still have uploaded successfully. Please log in to #{uri.host} interactively to check", :red)
            false
          when Net::HTTPRedirection, Net::HTTPForbidden, Net::HTTPUnauthorized
            say("#{resp.message} (#{resp.code}) -- authentication failed", :red)
            false
          when Net::HTTPBadRequest
            say("Server rejected package #{resp.body}", :red)
            false
          when Net::HTTPSuccess, Net::HTTPCreated
            say_verbose('Upload accepted', :green)
            begin
              JSON.parse(resp.body)
            rescue StandardError
              say('Package submission succeeded, but response was not valid JSON', :yellow)
              say("Content type: #{resp['Content-Type']})", :yellow)
              say(resp.body, :yellow)
              true
            end
          when Net::HTTPAccepted
            shell.say('Upload accepted, no text response received (this generally means OK)', :yellow)
            true
          else
            say(resp.inspect, :red)
            say("Failed request: #{resp.code} : #{resp.message}", :red)
            false
          end
        end
      end

      def faraday_post
        Faraday.post do |req|
          req.url = url
          req.headers['Content-Type'] = type
          req.headers['Accept'] = 'application/json'
          req.body = Faraday::UploadIO.new(filename, type)
        end
      end
    end # DefaultClient
  end
end
