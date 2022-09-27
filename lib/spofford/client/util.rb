require 'thor'
require 'zip'

module Spofford
  module Client
    # Utilities for working with data encountered by the client
    module Util
      # test a zip file to see if it's empty
      def zip_empty?(filename)
        empty = true
        begin
          File.open(filename) do |f|
            Zip::File.open(f) { |zip| empty = zip.entries.length.zero? }
          end
        rescue StandardError
          empty = true
        end
        empty
      end

      # convert a file containing identifiers one per line to a JSON array
      def lines_to_json(file)
        ids = []
        File.open(file) do |f|
          f.each_line { |x| ids << x.strip }
        end
        ids.flatten.to_json
      end

      # convert a file containing delimited identifiers to a JSON array
      # file may contain multiple lines.
      def delimited_file_to_json(file, delimiter = ',')
        ids = []
        File.open(file) do |f|
          f.each_line do |l|
            ids << l.split(delimiter).collect(&:strip)
          end
        end
        ids.flatten.to_json
      end

      # Wrap Thor's logger to make it easier to control
      # what gets logged
      module ThorLogger
        def shell
          @shell ||= ($stdout.isatty ? Thor::Shell::Color.new : Thor::Shell::Basic.new )
        end

        # default implementation
        def verbose?
          false
        end

        def report(msg, color = :red)
          shell.say("#{self.class.name}] #{msg}", color)
          nil
        end

        def say(msg, color = :yellow)
          shell.say("[#{self.class.name}] #{msg}", color)
          nil
        end

        def say_verbose(msg, color = :green)
          shell.say("[#{self.class.name}] #{msg}", color) if verbose?
          nil
        end
      end
    end
  end
end
