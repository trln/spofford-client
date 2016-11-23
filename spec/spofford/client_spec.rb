require 'spec_helper'

describe Spofford::Client do

  context 'module tests' do
    it 'has a version number' do
      expect(Spofford::Client::VERSION).not_to be nil
    end

    it 'uses default config' do
      expect(Spofford::Config.get).to eq(Spofford::Config::DEFAULT_CONFIG)
    end

    it 'allows JSON files' do
      expect(Spofford::Client.check_content_type('application/json')).to be(true)
    end

    it 'allows ZIP files' do
      expect(Spofford::Client.check_content_type('application/zip')).to be(true)
    end

    it 'detects JSON file extension' do
      testfile = Tempfile.new(["spofford-client-rspec", ".json"])
      begin
        testfile.write(%q|{ "data": "some dummy data"}|)
        expect(Spofford::Client::detect_content_type(testfile)).to eq('application/json')
      ensure
        testfile.close
        testfile.unlink
      end
    end

    it 'detects ZIP file extension' do
      testfile = Tempfile.new(["spofford-client-rspec", ".zip"])
      begin
        testfile.write(%q|{ "data": "some dummy data"}|)
        expect(Spofford::Client::detect_content_type(testfile)).to eq('application/zip')
      ensure
        testfile.close
        testfile.unlink
      end
    end


  end

  context 'default instance' do


    before(:each) do
      stub_request(:post, /\/ingest\/.*/)
          .with( headers: { 'Content-Type' => 'application/json' })
          .to_return(:status => 204, :body => %q|{"result" : "json"}|, :headers => {'Content-Type'=> 'application/json'})

      stub_request(:post, /\/ingest\/.*/)
          .with( headers: { 'Content-Type' => 'application/zip' })
          .to_return(:status => 204, :body => %q|{"result":"zip"}|, :headers => {'Content-Type' => 'application/json'})

      @instance = Spofford::Client.create
    end

    it 'raises RuntimeError when file does not exist' do
      expect { @instance.send('does-not-exist.txt') }.to raise_error(RuntimeError, /File does-not-exist/)
    end

    it 'successfully POSTS a JSON file' do
      testfile = Tempfile.new(["spofford-client-rspec-post", ".json"])
      begin
        testfile.write(%q|{"test":"data"}|)
        response = @instance.send(testfile)
        expect(response).not_to be_nil
        expect(JSON.parse(response.body)['result']).to eq('json')
      ensure
        testfile.close
        testfile.unlink
      end
    end

    it 'successfully POSTS a ZIP file' do
      testfile = Tempfile.new(["spofford-client-rspec-post", ".zip"])
      begin
        testfile.write(%q|{"test":"data"}|)
        response = @instance.send(testfile)
        expect(response).not_to be nil
        data = JSON.parse(response.body)
        expect(data['result']).to eq('zip')
      ensure
        testfile.close
        testfile.unlink
      end
    end




  end
end

