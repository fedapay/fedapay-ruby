
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fedapay/version'

Gem::Specification.new do |spec|
  spec.name          = 'fedapay'
  spec.version       = FedaPay::VERSION
  spec.authors       = ['Maelle AHOUMENOU', 'Boris Koumondji', 'Eric AKPLA']
  spec.email         = ['senma94@gmail.com', 'kplaricos@gmail.com']

  spec.summary       = 'Ruby library for FedaPay https://fedapay.com.'
  spec.description   = 'FedaPay is the easiest way to accept mobile money payments online.'
  spec.homepage      = 'https://github.com/fedapay/fedapay-ruby'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faraday'
  spec.add_dependency 'activesupport'
end
