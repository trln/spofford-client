require 'spec_helper'

describe 'Spofford::Client::Config' do
  class Context
    include Spofford::Client::Config
  end

  before(:each) do
    @context = Context.new
  end

  it 'loads default configuration with nil argument' do
    expect(@context.load_config(nil)).to eq(Spofford::Client::Config::DEFAULT_CONFIG)
  end

  describe '.guess_account' do
    it 'works even if env vars are not set' do
      allow(ENV).to receive(:[]).with('USER') { nil }
      allow(ENV).to receive(:[]).with('USERNAME') { nil }
      expect(Spofford::Client::Config.guess_account).to match /^nobody@/
    end
  end
end
