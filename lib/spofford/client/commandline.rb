require 'thor'
require 'spofford/client'

module Spofford
  module Client
    # Implementation of the commands
    class CommandLine < Thor
      include Thor::Actions
      include Spofford::Client::Config

      map %w[--version -v] => :__version

      desc '--version, -v', 'print the version'
      def __version
        puts "Spofford client version #{Spofford::Client::VERSION}, installed #{File.mtime(__FILE__)}"
      end

      desc 'testing', 'Tests some stuff that is not well documented'
      def testing
        say 'this is me in amber', :yellow
      end

      desc 'configure', 'Creates a new configuration'
      long_desc <<-LONGDESC
      Performs initial (or alternate) configuration of the client,
      allowing you to set the URL to the spofford instance, your account name,
      and set options such as whether to automatically create .zip ingest packages

      Note that this will overwrite the configuration, so make sure you have a backup!
      LONGDESC
      method_option :config, aliases: '-c', type: :string, desc: 'Configuration file'
      method_option :verbose, alias: '-v', type: :boolean, default: false, desc: 'Output defaults, etc.'
      def configure
        dest = options[:file] || default_location
        if File.exist?(dest)
          exit 0 unless yes?("A configuration file at #{dest} already exists.  Do you want to overwrite it? (Y/N)")
        end
        config = {}.update(DEFAULT_CONFIG)
        action_description = File.exist?(dest) ? 'Updating' : 'Creating'
        say("#{action_description} configuration at #{location}", :yellow) if config[:verbose]
        config.update(load_config(dest)) if File.exist?(dest)
        CONFIG_OPTIONS.each do |key, opt|
          options = ''
          next unless opt[:configure]

          current_val = case opt[:type]
                        when :boolean
                          options = '(Y/N)'
                          config[key] ? 'Y' : 'N'
                        else
                          config[key]
                        end

          val = ask("#{opt[:description]} [#{current_val}] #{options}")
          next if val.nil? || val.empty? || /^\s*$/.match(val)

          result = case opt[:type]
                   when :boolean
                     %w[y true].include?(val.downcase)
                   else
                     val
                   end
          config[key] = result
        end
        say("Writing your configuration to #{location}", :yellow) if config[:verbose]
        if yes?('Do you want to generate a new access token (Y/N)?')
          new_token = Spofford::Client::Authenticator.new(config).new_token!
          config[:authentication_token] = new_token
        end
        save_config(config, dest)
      end

      desc 'authenticate', 'Creates a new authentication token and write it to your configuration'
      long_desc <<-LONGDESC
      In order to prevent applications from having to store passwords on disc,
      spofford allows submitting ingest packages using an authentication token.

      This feature creates a new authentication token, which will be stored
      inside the configuration and is required for use of the client in a non-
      interactive situation (e.g. a cron job)

      Note that Spofford accounts can have only one authentication token, so
      invoking this option will de-authenticate any other client instances bound
      to the same account.
      LONGDESC
      method_option :config, aliases: '-c', type: :string, desc: 'Configuration file'
      def authenticate
        dest = options[:config] || default_location
        raise "No existing configuration file at #{dest} : please create one first with 'configure'" unless File.exist?(dest)
        configuration = load_config(dest)
        exit unless ask("This will clear any existing access tokens for #{configuration[:spofford_account_name]}, do you want to proceed (Y/N)?")
        auther = Spofford::Client::Authenticator.new(configuration)
        new_token = auther.new_token!
        configuration[:authentication_token] = new_token
        save_config(configuration, dest)
        say('New authentication token created and stored.', :green)
      end

      desc 'ingest', 'Submits file(s) to Spofford'
      long_desc <<-LONGDESC
            Submits one or more files to Spofford.  By default, loads configuration
            (including URL to submit to and account information) from the default
            configuration file, which can be created with the 'configure' command.

            If only one filename is supplied, format will be guessed from its
            extension (i.e. `.zip` means the file contains an ingest package
            containing an optional deletion file and zero or more Argot files;
            `.json` will be interpreted as a single file containing Argot.
      LONGDESC
      method_option :config,
                    alias: '-c',
                    desc: 'Configuration file to use'

      method_option :json,
                    desc: 'Skip packaging, submit single JSON file'
      method_option :base_url,
                    alias: '-u',
                    desc: 'Override base URL'
      method_option :account,
                    alias: '-a',
                    desc: 'Override Spofford account name'
      method_option :manifest,
                    alias: '-m',
                    default: '-',
                    desc: 'Read files to be packaged from manifest; named file or STDIN if no name given'
      method_option :output,
                    desc: 'Override destination for created ingest packages'
      method_option :verbose,
                    alias: '-v',
                    type: :boolean,
                    default: false,
                    desc: 'Be chatty creating packages and sending them to spofford'
      method_option :debug,
                    default: false,
                    desc: 'Output HTTP operation details to standard error'
      def ingest(*files)
        verbose = options[:verbose]
        manifest_file = options[:manifest]
        say("manifest file: #{manifest_file}", :green) if verbose
        if files.empty? && manifest_file == '-'
          say("Reading list of files to process from STDIN\n", :green) if verbose
          files = $stdin.each_line.collect(&:itself).map(&:strip).reject(&:empty?)
        elsif files.empty?
          say("reading manifest from #{manifest_file}") if verbose
          files = File.open(manifest_file) do |f|
            f.each_line.collect(&:itself).map(&:strip).reject(&:empty?)
          end
        end
        say("Can't call ingest without some files!", :red) && exit(1) if files.empty?
        config = options[:config] ? load_config(options[:config]) : load_config
        raise "Interactive option is not currently supported, sorry!" if options[:interactive]
        %i[interactive verbose debug].each do |k|
          config[k] = true if options[k]
        end
        if options[:account]
          say("Setting spofford account name to #{options[:account]}", :green) if verbose
          config[:spofford_account_name] = options[:account]
        end
        client = Spofford::Client.create(config)

        result = if options[:json]
                   say("Skipping packager, submitting JSON file #{files[0]}", :green) if verbose
                   client.send(files[0])
                 else
                   begin
                     files = Spofford::Client::Packager.new(files, config).package
                   rescue Spofford::Client::Packager::NoFilesError => e
                     say(e, :red)
                     exit(1)
                   end
                   client.send(Spofford::Client::Packager.new(files, config).package)
                 end
        if result
          say("package successfully uploaded: #{result}", :green)
        else

          say("Ingest submission failed, #{result}", :red)
        end
      end

      desc 'package', 'Creates an ingest package (but does not submit it)'
      method_option :test, aliases: '-t', type: :boolean, default: false, desc: 'Test only, do not create package'
      method_option :output, aliases: '-o', desc: 'Output file or directory'
      method_option :config, aliases: '-c', type: :string, desc: 'use configuration file'
      method_option :verbose, aliases: '-v', type: :boolean, default: false, desc: 'Output info about what we are doing'
      def package(*files)
        package_options = { test: options['test'], verbose: options['verbose'] }
        config = (options['config'] ? load_config(options['config']) : load_config).clone
        if (destination = options['output'])
          package_options[:output] = destination
        end
        config.update(package_options)       
        packager = Spofford::Client::Packager.new(files, config)
        begin
          output = packager.package
          say("Created #{output}", :green)
        rescue Spofford::Client::Packager::NoFilesError => e
          say(e, :red)
          exit 1
        end
      end

      #default_task :ingest
    end
  end
end
