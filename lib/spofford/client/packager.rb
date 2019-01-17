require 'zip'
require 'fileutils'
require 'tempfile'

module Spofford
  module Client
    # Utilities to help with mapping files supplied at command line to
    # the files that will be ingested
    module Ingest
      include Spofford::Client::Util
      include Spofford::Client::Util::ThorLogger

      class NoFilesError < StandardError
      end

      def verbose?
        defined @verbose ? @verbose : false
      end

      # allows for auto-conversion of non-JSON-array delete files
      # when `filename` is a text file with an ID on each line,
      # converts to a JSON array and writes to a tempfile
      def map_delete_file(filename)
        say_verbose("Mapping delete file #{filename}", :cyan)
        # where to read the data from
        source = nil
        # what it will be called in the zip file
        result = filename
        data = file_data(filename)
        source, result = tempstore_data(filename, data) unless data.nil?
        say_verbose("#{filename} => source: #{source}, zipname: #{result}", :cyan)
        # note source will be nil when we didn't have to monkey with the filename
        { source: source, zipname: File.basename(result) }
      end

      def tempstore_data(filename, data)
        say_verbose("Creating temp JSON array file from #{filename}", :cyan)
        prefix = File.basename(filename, File.extname(filename))
        result = "#{prefix}.json"
        source = Tempfile.new(['delete-', '.json'])
        source.write(data)
        source.close
        [source.path, result]
      end

      def file_data(filename)
        case File.extname(filename)
        when '.json'
          say_verbose("#{filename} looks like JSON, will not transform", :cyan)
        when '.csv'
          say_verbose("#{filename} looks like CSV, will convert to JSON array", :cyan)
          delimited_file_to_json(filename)
        else
          say_verbose("#{filename} cannot determine format, will convert id-per-line to JSON", :cyan)
          lines_to_json(filename)
        end
      end

      # creates a list of hashes, with source file names and the resulting name
      # in the zip
      def map_ingest_files(files)
        files.collect do |fn|
          result = fn.downcase
          result_base = File.basename(result)
          say_verbose("Packager: input #{fn} will be processed as #{result_base} -- ", :cyan)
          if result_base.start_with?('delete')
            say_verbose("#{result} looks like a delete file", :cyan)
            d = map_delete_file(result)
            d[:source] ||= fn
            say_verbose(" -- JSON delete file:  #{d.to_s}", :cyan)
            d
          elsif result_base.start_with?('add')
            say_verbose("#{result} looks like an add/update file, zipname: #{result_base}", :cyan)
            { source: fn, zipname: result_base }
          elsif result_base.include?('argot') && File.extname(result) == '.json'
            say_verbose("#{result} is a JSON file with 'argot' in the name, will add zipfile: add-#{result_base}", :cyan)
            { source: fn, zipname: "add-#{result_base}" }
          end
        end.compact
      end
    end

    class Packager
      include Spofford::Client::Ingest
      include Spofford::Client::Util::ThorLogger

      DEFAULT_ZIP_NAME = 'spofford-ingest.zip'.freeze

      attr_accessor(:files, :output, :zipfile)

      def initialize(filenames = [], options = {})
        @dry_run = options.fetch(:test, false)
        @files = [].push(*filenames)
        # we are always verbose on a dry run
        @verbose = options.fetch(:verbose, false) || @dry_run
        @zipfile = find_destination(options)
      end

      def verbose?
        @verbose
      end

      def <<(file)
        @files << file
      end

      def package
        @package ||= make_package
      end

      private

      def find_destination(options = {})
        destination = options[:output]
        output = if destination.nil?
                   say_verbose('output option not set, using default', :cyan)
                   DEFAULT_ZIP_NAME
                 elsif File.extname(destination) == '.zip'
                   say_verbose('output option has .zip extension, using as filename', :cyan)
                   destination
                 elsif File.directory?(destination) || !File.exist?(destination)
                   say_verbose(":output (#{destination}) is directory, creating timestamped file", :cyan)
                   File.join(destination, "spofford-ingest-#{Time.now.strftime('%Y%m%dT%H%M%S')}.zip")
                 else
                   say_verbose("Unable to determine output type: #{destination}", :cyan)
                 end
        output || DEFAULT_ZIP_NAME
      end

      ## determines what needs to be ingested and
      # returns the path to the file
      # if none of the files addded exist, raises an exception
      # if the first existing file is a zip (based on extension)
      # returns its name
      # Otherwise, creates the zip package and returns its path.
      # Zip creation is skipped if the :test option
      def make_package
        local_package = @files.select do |f|
          say_verbose("Inspecting #{f}")
          if File.exist?(f)
            say_verbose("Selecting file #{File.basename(f)}") if @dry_run
            true
          else
            say_verbose("Can't find file #{File.basename(f)}", :cyan) if @dry_run
            false
          end
        end
        if local_package.empty?
          raise NoFilesError, 'No readable input files found'
        end

        if File.extname(local_package[0]) == '.zip'
          say('First filename supplied is a zip, using that as ingest package', :green)
          return local_package[0]
        end

        mapped_filenames = map_ingest_files(local_package)
        say_verbose("Files going into zip: #{mapped_filenames}", :yellow)
        if mapped_filenames.nil? || mapped_filenames.empty?
          raise NoFilesError, "Unable to determine ingest type for the supplied filenames, no package created"
          return []
        end

        unless @dry_run
          abs_dir = File.dirname(File.absolute_path(@zipfile))
          FileUtils.mkdir_p(abs_dir) unless File.directory?(abs_dir)
          Zip::File.open(@zipfile, Zip::File::CREATE) do |zipfile|
            mapped_filenames.each do |filenames|
              say("Here is the filenames thingy: #{filenames}")
              say_verbose("Adding #{filenames[:source]} to zip file as #{filenames[:zipname]}", :green)
              zipfile.add(filenames[:zipname], filenames[:source])
            end
          end
        end
        @zipfile
      end
    end
  end
end
