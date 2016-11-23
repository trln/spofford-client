$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'spofford/client'
require 'webmock/rspec'
require 'tempfile'

WebMock.disable_net_connect!(:allow_localhost => false)

