require 'spec_helper'
require 'tempfile'

describe 'Spofford::Client::Util' do
  class Context
    include Spofford::Client::Util
  end

  before(:each) do
    @ids = %w[lorem ipsum dolor si amet]
    @lines = Tempfile.new(['spec_spofford_client', '.txt'])
    @ids.each { |x| @lines.write("#{x}\n") }
    @lines.close
    @commas = Tempfile.new(['spec_spofford_client', '.csv'])
    @commas.puts(@ids.join(','))
    @commas.puts(@ids.join(','))
    @commas.close
    @context = Context.new
  end

  it 'correctly reads back ids written one to a line' do
    result = @context.lines_to_json(@lines.path)
    expect(result).to eq(@ids.to_json)
  end

  it 'correct reads back ids written to delimited file' do
    doubled = @ids + @ids
    result = @context.delimited_file_to_json(@commas.path)
    expect(result).to eq(doubled.to_json)
  end
end
