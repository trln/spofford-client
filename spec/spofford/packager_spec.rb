require 'spec_helper'

describe 'Spofford::Client::Packager' do
  # allows capturing stdout when running packager in verbose mode
  module Capture
    def self.capture
      orig_out = $stdout
      out = StringIO.new
      begin
        $stdout= out
        yield 
      ensure
        $stdout = orig_out
      end
      out.string
    end
  end

  context 'with defaults' do
    before(:each) do
      @instance = Spofford::Client::Packager.new
    end

    it 'has an empty files array' do
      expect(@instance.files).to be_empty
    end

    it 'has the expected zip filename' do
      expect(@instance.zipfile).to start_with('spofford-ingest')
    end
  end

  context 'initialize with two line-per-id delete files' do
    before(:each) do
      @deletes = %w[NCSU12345 NCSU987654]
      f = Tempfile.new(["delete-", '.txt'])
      @deletes.each { |x| f.puts(x) }
      f.close

      f1 = Tempfile.new('delete-')
      @deletes.each { |x| f1.puts(x) }
      f1.close

      @instance = Spofford::Client::Packager.new([f.path, f1.path], verbose:true)
    end

    it 'creates a package with two delete JSON files' do
      result = nil
      output = Capture.capture do 
        result = @instance.package
      end
      expect(File.exist?(result)).to be(true)
      contents = []
      Zip::File.open(result) do |zipfile|
        zipfile.each do |entry|
          contents << [ entry.name, JSON.parse(entry.get_input_stream.read) ]
        end
      end
      expect(contents.length).to eq(2)
      contents.each do |entry|
        expect(entry[1]).to eq(@deletes)
      end
    end

    after(:each) do 
      File.unlink(@instance.package) if File.exist?(@instance.package)
    end
  end

  context 'initialize with empty files, add later' do
    before(:each) do
      @add1 = { owner: 'ncsu', id: 'NCSU12345' }
      @add2 = { owner: 'ncsu', id: 'NCSU987654' }
      @deletes = %w[NCSU12345 NCSU987654]
      @the_files = [['add_1', @add1], ['add_2', @add2], ['delete', @deletes]].collect do |pair|
        f = Tempfile.new([pair[0], '.json'])
        f.write(pair[1].to_json)
        f.close
        f.path
      end
      @instance = Spofford::Client::Packager.new
    end

    after(:each) do
      File.unlink(@instance.zipfile) if File.exist?(@instance.zipfile)
    end

    it 'creates a zip with files added with <<' do
      @the_files.each do |f|
        @instance << f
      end
        contents = []
      Zip::File.open(@instance.package) do |zipfile|
        zipfile.each do |entry|
          contents << entry.name
        end
      end
      expect(contents.length).to eq(3)
      expect(contents).to include(/add_1.*\.json/)
      expect(contents).to include(/add_2.*\.json/)
      expect(contents).to include(/delete.*\.json/)
      expect(contents).not_to include(/denoberate.*\.json/)
    end
  end

  context '.initialize with some files' do
    before(:each) do
      @add1 = { owner: 'ncsu', id: 'NCSU12345' }
      @add2 = { owner: 'ncsu', id: 'NCSU987654' }
      @deletes = %w[NCSU12345 NCSU987654]
      @the_files = [['add_1', @add1], ['add_2', @add2], ['delete', @deletes]].collect do |pair|
        f = Tempfile.new([pair[0], '.json'])
        f.write(pair[1].to_json)
        f.close
        f.path
      end
      @instance = Spofford::Client::Packager.new(@the_files, verbose: true)
    end

    after(:each) do
      File.unlink(@instance.zipfile) if File.exist?(@instance.zipfile)
    end

    it 'creates a ZIP' do
      output = Capture.capture do
        expect(@instance.package).to eq(@instance.zipfile)
        expect(File).to exist(@instance.zipfile)
      end
      expect(output).not_to be_nil
    end

    it 'creates a ZIP with the expected number of files' do
      output = Capture.capture do
        contents = []
        Zip::File.open(@instance.package) do |zipfile|
          zipfile.each do |entry|
            contents << entry.name
          end
        end
        expect(contents.length).to eq(3)
        expect(contents).to include(/add_1.*\.json/)
        expect(contents).to include(/add_2.*\.json/)
        expect(contents).to include(/delete.*\.json/)
        expect(contents).not_to include(/denoberate.*\.json/)
      end
      expect(output).not_to be_nil
    end
  end # with some files
end
