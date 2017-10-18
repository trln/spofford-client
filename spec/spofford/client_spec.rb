require 'spec_helper'

require 'zip'

describe Spofford::Client do
  class Context
    include Spofford::Client
  end

  before(:each) do
    @context = Context.new
  end

  context 'module tests' do
    it 'has a version number' do
      expect(Spofford::Client::VERSION).not_to be nil
    end

    it 'allows JSON files' do
      expect(@context.accepts_type?('application/json')).to be(true)
    end

    it 'allows ZIP files' do
      expect(@context.accepts_type?('application/zip')).to be(true)
    end

    it 'detects JSON file extension' do
      testfile = Tempfile.new(['spofford-client-rspec', '.json'])
      begin
        testfile.write({ 'data' => 'some dummy data' }.to_json)
        expect(@context.detect_content_type(testfile)).to eq('application/json')
      ensure
        testfile.close
        testfile.unlink
      end
    end

    it 'detects ZIP file extension' do
      testfile = Tempfile.new(['spofford-client-rspec', '.zip'])
      begin
        testfile.write({ 'data' => 'some dummy data' }.to_json)
        expect(@context.detect_content_type(testfile)).to eq('application/zip')
      ensure
        testfile.close
        testfile.unlink
      end
    end
  end

  context 'default instance' do
    before(:each) do
      stub_request(:post, /\/ingest\/.*/)
        .with(headers: { 'Content-Type' => 'application/json' })
        .to_return(status: 201, body: '{"result" : "json"}', headers: { 'Content-Type' => 'application/json' })

      stub_request(:post, /\/ingest\/.*/)
        .with(headers: { 'Content-Type' => 'application/zip' })
        .to_return(status: 201, body: '{"result":"zip"}', headers: { 'Content-Type' => 'application/json' })

      @instance = Spofford::Client.create
    end

    it 'raises RuntimeError when file does not exist' do
      expect { @instance.send('does-not-exist.txt') }.to raise_error(RuntimeError, /File does-not-exist/)
    end

    it 'successfully POSTS a JSON file' do
      testfile = Tempfile.new(['spofford-client-rspec-post', '.json'])
      begin
        testfile.write('{"test":"data"}')
        response = @instance.send(testfile)
        expect(response).not_to be_nil
        expect(response['result']).to eq('json')
      ensure
        testfile.close
        testfile.unlink
      end
    end

    it 'successfully POSTS a ZIP file' do
      testfile = Tempfile.new(['spofford-client-rspec-post', '.zip'])
      begin
        Zip::File.open(testfile.path, Zip::File::CREATE) do |zip|
          zip.get_output_stream('data') { |out| out.write('{"test":"data"}') }
        end
        response = @instance.send(testfile)
        expect(response).not_to be nil
        expect(response['result']).to eq('zip')
      ensure
        testfile.close
        testfile.unlink
      end
    end
  end
end
