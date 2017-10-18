require 'spec_helper'

describe Spofford::Client::CommandLine do
  context 'Basic Syntax Check' do
    it 'does not contain a syntax error' do
      thor = Spofford::Client::CommandLine.new
      expect(thor).not_to be_nil
    end
  end
end
