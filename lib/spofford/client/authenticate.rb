require 'io/console'
require 'nokogiri'
require 'faraday/follow_redirects'
require 'faraday-cookie_jar'

module Spofford
  module Client
    # Class to handle obtaining of new authentication tokens.
    class Authenticator
      # relative URL from spofford root to the user's own page
      # URL to generate new token is found here.
      USER_PAGE_URL = 'trln/users/me'.freeze

      def initialize(config)
        @config = config
      end

      def logger
        @logger ||= create_logger
      end

      def client
        @client ||= create_client
      end

      def user_page_url
        @user_page_url ||= URI.join(@config[:base_url], @config.fetch(:user_page_url, USER_PAGE_URL))
      end

      # Attempt authentication and prepare to make a request for a new
      # authentication token that can be used to submit ingest packages
      # workflow is to attempt to access the user's page in Spofford, which
      # will force the user to login; ask for credentials on the command line
      # as needed, and then submit the login form; if this succeeds,
      # return the response, which will contain the body of the
      # form that allows us to request a new token
      def authenticate
        logger.debug("Attempting to authenticate at #{user_page_url}")
        resp = client.get(user_page_url)
        logger.debug("and here is the response: #{resp} #{resp.class}")
        if resp.status != 200
          logger.warn("Unable to fetch #{user_page_url}")
          logger.warn("Response: #{resp.status} : #{resp.reason_phrase}")
          logger.info(resp.body) if resp.respond_to?(:body)
          return false
        end
        # we actually have the response for the login page form now
        form = Nokogiri::HTML(resp.body).css('form#new_user')
        username, pw = read_credentials
        login_form = complete_login_form(form, username, pw)
        resp = do_login(login_form)
        if resp.status != 200
          raise "Authentication failed: #{resp.status}: #{resp.reason_phrase}"
        end
        resp
      end

      # obtains a new access token, assuming we've already authenticated
      # @param [Faraday::Response] user_page_response a successful response
      # from #authenticate.
      # @return [String] the new token
      def obtain_new_token(user_page_response)
        form = Nokogiri::HTML(user_page_response.body).css('form#new_token')
        action = form.attribute('action')
        raise Spofford::Client::AuthenticationError, "Can't access token creation; check password" if action.nil?
        uri = URI.join(user_page_url, action.value)
        params = collect_params(form)
        logger.debug("Obtaining token from #{uri}")
        resp = post_form(uri, params)
        # the token should just be the body of the request
        unless resp.status == 200
          logger.info(resp.body)
          raise "Unable to obtain new token: #{resp.status} : #{resp.body}"
        end
        resp.body.strip
      end

      # authenticates and obtains a new access token, in one step.
      def new_token!
        auth_result = authenticate
        if auth_result
          obtain_new_token(auth_result)
        else
          warn("Unable to create new token.  Initial authentication failed, see log messages")
        end
      end

      def complete_login_form(form, user, passwd)
        action = form.attribute('action').value
        params = collect_params(form)
        params['action'] = action
        params['user[email]'] = user
        params['user[password]'] = passwd
        params['user[remember_me]'] = 0 if params.key?('user[remember_me]')
        params
      end

      private

      def create_logger
        level = Logger.const_get(@config.fetch(:log_level, 'WARN').upcase)
        log = Logger.new(STDERR)
        log.level = level
        log
      end

      def post_form(uri, params, headers = {})
        client.post(uri) do |req|
          req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          req.body = URI.encode_www_form(params)
        end
      end

      # collects the input elements in form as a hash of name/value pairs;
      # this can only handle simple forms (no textareas, multiple values,
      # etc.)
      def collect_params(form)
        Hash[form.css('input').collect { |i| [i['name'], i['value']]}]
      end

      def do_login(params)
        form_url = URI.join(@config[:base_url], params['action'])
        logger.debug("POSTing login to #{form_url}")
        post_form(form_url, params)
      end

      def create_client
        Faraday.new do |conn|
          conn.response :follow_redirects
          conn.use :cookie_jar
          conn.adapter Faraday.default_adapter
        end
      end

      def read_credentials
        unless @config[:spofford_account_name]
          $stdout.write('username (email): ')
          username = gets.chomp
          @config[:spofford_account_name] = username
        end
        username ||= @config[:spofford_account_name]
        $stdout.write('password: ')
        pw = STDIN.noecho(&:gets).chomp
        $stdout.write("\r\n")
        [username, pw]
      end
    end
  end
end
