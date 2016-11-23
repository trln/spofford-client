require 'yaml'
require 'socket'

module Spofford

  def self.guess_owner
    hostname = Socket.gethostname
    m = /\.([a-z]+)\.edu$/.match(hostname.downcase)
    if m
      return m[1]
    end
    '<unknown>'
  end

  module Config

    attr_accessor :config

    # Descriptions to help provide documentation and create configuration
    # files on command line
    # :description is required
    # :configure allows it to be set without directly editing the file (base options)
    #   -- default false
    # :type is used to allow special handling for booleans, ints, etc.
    #   -- default string (no special handling)
    OPTIONS = {
        :base_url => { :description => 'Base URL of Spofford service',
                       :configure => true
        },
        :owner => { :description => 'Owner (institution) for submitted records',
                    :configure => true
        },
        :package_storage_location => {
            :description => 'Directory or filename for ingest packages',
            :configure => true,
        },
        :force_zip => {
            :description => 'Force creation of zip ingest package (y/n)',
            :configure => true,
            :type => :boolean,
        }

    }


    DEFAULT_CONFIG = {
          :base_url => 'http://localhost:3000',
          :package_storage_location => File.join(Dir.getwd, 'packages'),
          :owner => Spofford.guess_owner,
          :package_only => false,
          :force_zip => false,
          :verbose => false,
      }

    def self.config(location=File.join(Dir.getwd, 'config.yml'))
      @config ||= self.load(location)
    end

    def self.deepcopy(input_hash)
      Marshal.load(Marshal.dump(input_hash))
    end

    def self.load(location)
      _config = deepcopy(DEFAULT_CONFIG)
      if File.exist?(location)
        _config.update(*(YAML.load(File.open(location))))
      end
      _config
    end

    def self.create_config(location)
          config = {}.update(DEFAULT_CONFIG)
          puts "Creating/updating configuration at #{location}" if config[:verbose]
          if File.exist?(location)
            puts "Loading existing configuration from #{location}" if config[:verbose]
            config.update(YAML.load(File.open(location))) if File.exists?(location)
          end
          OPTIONS.each do |key, opt|
            options = ""
            next unless opt[:configure]
            current_val = case opt[:type]
              when :boolean
                options = '(Y/N)'
                config[key] ? 'Y' : 'N'
              else
                config[key]
            end

            puts "#{opt[:description]} [#{current_val}] #{options}: "
            val = gets.chomp
            unless val.nil? or val.empty? or /^\s*$/.match(val)
              result = case opt[:type]
                when :boolean
                  %w[y true].include?(val.downcase)
                else
                  val
              end
              config[key] = result
            end
          end
          puts "Writing your configuration to #{location}" if config[:verbose]
          File.open(location, "w") do |file|
              file.write (config.to_yaml)
          end
          location
      end
    end
end
