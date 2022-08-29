lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spofford/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'spofford-client'
  spec.version       = Spofford::Client::VERSION
  spec.authors       = ['Adam Constabaris']
  spec.email         = ['adam_constabaris@ncsu.edu']

  spec.summary       = 'Client utility for the TRLN record ingest application.'
  spec.homepage      = 'https://github.com/trln/spofford-client'

  raise 'Please use RubyGems 2.0 or newer.' unless spec.respond_to?(:metadata)

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'faraday', '~> 2.0'
  spec.add_runtime_dependency 'faraday-cookie_jar'

  spec.add_runtime_dependency 'mimemagic', '~> 0.4'
  spec.add_runtime_dependency 'nokogiri', '~> 1.8'
  spec.add_runtime_dependency 'rubyzip', '~> 2.0'
  spec.add_runtime_dependency 'thor', '~> 1.0'

  spec.add_development_dependency 'bundler', '>= 1.10'
  spec.add_development_dependency 'rake', '>= 12.3'
  spec.add_development_dependency 'rspec', '>= 3.8'
  spec.add_development_dependency 'webmock', '>= 3.5'
end
