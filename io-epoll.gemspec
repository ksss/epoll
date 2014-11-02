Gem::Specification.new do |spec|
  spec.name          = "io-epoll"
  spec.version       = "0.1.0"
  spec.authors       = ["ksss"]
  spec.email         = ["co000ri@gmail.com"]
  spec.summary       = %q{An experimental binding of epoll(7)}
  spec.description   = %q{An experimental binding of epoll(7)}
  spec.homepage      = "https://github.com/ksss/io-epoll"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/io/epoll/extconf.rb"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'test-unit'
end
