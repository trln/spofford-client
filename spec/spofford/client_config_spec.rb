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
end
