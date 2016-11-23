require 'spec_helper'

describe 'Spofford::Client::Packager' do
  context '.intiialize with defaults' do
    before(:each) do
      @instance = Spofford::Client::Packager.new
    end

    it 'has an empty files array' do
      expect(@instance.files).to be_empty
    end

    it 'does not force zipfile creation' do
      expect(@instance.force_zip).to be false
    end

    it 'has the expected zip filename' do
      expect(@instance.zipfile).to start_with("spofford-ingest-")
    end

  end

  context '.initialize with some files' do
    before(:each) do
      @add1 = { :owner => 'ncsu', :id => "NCSU12345" }
      @add2 = { :owner => 'ncsu', :id => "NCSU987654" }
      @deletes = [ "NCSU12345", "NCSU987654" ]
      @the_files = [ ["add_1", @add1], ["add_2", @add2], [ "delete", @deletes] ].collect do |pair|
        f = Tempfile.new([pair[0], '.json'])
        f.write(pair[1].to_json)
        f
      end
      @instance = Spofford::Client::Packager.new(@the_files)
    end

    after(:each) do
      File.unlink(@instance.zipfile) if File.exist?(@instance.zipfile)
    end

    it 'creates a ZIP' do
      expect(@instance.get_package).to eq(@instance.zipfile)
      expect(File).to exist(@instance.zipfile)
    end

    it 'creates a ZIP with the expected number of files' do
      contents = []
      Zip::File.open(@instance.get_package) do |zipfile|
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



  end # with some files

end
