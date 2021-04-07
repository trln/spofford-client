require 'yaml'
require 'socket'

module Spofford
  module Client
    # Configuration for a spofford client instance.
    module Config
      # Utility to guess the default owner for this
      # configuration based on the hostname
      def self.guess_owner
        hostname = Socket.gethostname
        m = /\.([a-z]+)\.edu$/.match(hostname.downcase)
        m ? m[1] : 'unknown'
      end

      # Guess the Spofford account name based on current user
      # and hostname
      def self.guess_account
        (ENV['USER'] || ENV['USERNAME'] || 'nobody') + "@#{guess_owner}.edu"
      end

      # Get the usual storage location for the configuration
      def default_location
        @@default_location ||= File.join(Dir.getwd, '.spofford-client.yml').freeze
      end

      # Descriptions to help provide documentation and create configuration
      # files on command line
      # :description is required
      # :configure allows it to be set without directly editing the file
      # (base options)
      #   -- default false
      # :type is used to allow special handling for booleans, ints, etc.
      #   -- default string (no special handling)
      CONFIG_OPTIONS = {
        base_url: {
          description: 'Base URL to Spofford service',
          configure: true
        },
        owner: {
          description: 'Default Owner (institution) for submitted records',
          configure: true
        },
        spofford_account_name: {
          description: 'User account name (email address) for Spofford',
          configure: true
        },
        output: {
          description: 'Directory or filename for created zip ingest packages',
          configure: true
        },
        force_zip: {
          description: 'Force creation of zip ingest package even when only one file is involved',
          configure: true,
          type: :boolean
        }
      }.freeze

      DEFAULT_CONFIG = {
        base_url: 'http://localhost:3000',
        output: File.join(Dir.getwd, 'packages'),
        owner: guess_owner,
        spofford_account_name: guess_account,
        package_only: false,
        force_zip: false,
        verbose: false,
        server_timeout: 120
      }.freeze

      def save_config(config, location = default_location)
        File.open(location, 'w') do |f|
          f.write desymbolize_keys(config).to_yaml
        end
      end

      # loads the configuration
      # @param location [String] the filename of the location to load; may be
      # `nil` in which case the default configuration will be loaded.
      def load_config(location = default_location)
        config = deepcopy(DEFAULT_CONFIG)
        if location && File.exist?(location)
          File.open(location) do |f|
            config.update(symbolize_keys(YAML.safe_load(f)))
          end
        end
        config
      end

      private

      # ensures all keys of a hash are symbols
      def symbolize_keys(hash)
        Hash[hash.collect { |k, v| [k.to_sym, v] }]
      end

      # ensures all keys of a has are strings
      def desymbolize_keys(hash)
        Hash[hash.collect { |k, v| [k.to_s, v] }]
      end

      def deepcopy(input_hash)
        Marshal.load(Marshal.dump(input_hash))
      end
    end
  end
end
