lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spofford/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'spofford-client'
  spec.version       = Spofford::Client::VERSION
  spec.authors       = ['Adam Constabaris']
  spec.email         = ['adam_constabaris@ncsu.edu']

  spec.summary       = 'Client utilities for Spofford, the TRLN record ingest application.'
  #spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."

  raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.' unless spec.respond_to?(:metadata)
  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'faraday', '~> 0.13'
  spec.add_runtime_dependency 'faraday_middleware', '~> 0.12'
  spec.add_runtime_dependency 'faraday-cookie_jar', '~> 0.0.6'
  spec.add_runtime_dependency 'mimemagic', '~> 0.3.2'
  spec.add_runtime_dependency 'rubyzip', '~> 1.2.0'
  spec.add_runtime_dependency 'nokogiri', '~> 1.8'
  spec.add_runtime_dependency 'thor', '~> 0.20.0'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.6.0'
  spec.add_development_dependency 'webmock', '~>3.1.0'
end
