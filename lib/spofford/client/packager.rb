require 'zip'
require 'fileutils'
module Spofford
  module Client
    class Packager

      attr_accessor(:files, :zipfile, :force_zip)

      def initialize(filenames=[], options={})
        @files = [].push(*filenames)
        if options[:package_storage_location]
          if File.extname(options[:package_storage_location]) == '.zip'
            options[:zipfile] = options[:package_storage_location]
          else
            options[:zipfile] = File.join(options[:package_storage_location], "spofford-ingest-#{Time.now.strftime('%Y%m%dH%M%S')}.zip")
          end
        end
        @dry_run = options[:test]
        @zipfile = options[:zipfile]
        @force_zip = options.has_key?(:force_zip) ? options[:force_zip] : false
      end

      def <<(file)
        @files << file
      end

      def get_package
        @package ||= make_package
      end

      private

      ## determines what needs to be ingested and
      # returns the path to the file
      # if none of the files addded exist, raises an exception
      # if only one file can be found, return its path
      # if multiple files were found, OR force_zip was set,
      # creates the zip pacakge and return its path
      # if the :test option was passed to the constructor,
      # skip zip creation.
      def make_package
        _package = @files.select { |f| File.exist?(f) }
        if _package.length == 0
            raise "No readable input files found"
        elsif _package.length == 1 and not @force_zip
           _package[0]
        else
          if not @dry_run
            abs_dir = File.dirname(File.absolute_path(@zipfile))
            unless File.directory?(abs_dir)
              puts "Creating #{abs_dir}"
              FileUtils.mkdir_p(abs_dir)
            end

            Zip::File.open(@zipfile, Zip::File::CREATE) do |zipfile|
              _package.each do |fn|
                zipfile.add(File.basename(fn), fn)
              end
            end
          end
          @zipfile
        end
      end
    end
  end
end