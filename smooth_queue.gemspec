
Gem::Specification.new do |gem|
  gem.name          = 'smooth_queue'
  gem.summary       = 'Simple Redis queue manager with flow control for Ruby apps'
  gem.description   = gem.summary
  gem.authors       = ['Rafael Sales']
  gem.email         = ['rafaelcds@gmail.com']
  gem.homepage      = 'https://github.com/rafaelsales/smooth_queue'
  gem.license       = 'MIT'
  gem.version       = '0.0.1'
  gem.executables   = %w[squeue smooth_queue]
  gem.require_paths = ['lib']

  gem.add_dependency 'redis', '~> 4.0', '>= 4.0.1'
  gem.add_dependency 'redis-namespace', '~> 1.6.0'
  gem.add_dependency 'connection_pool', '~> 2.2', '>= 2.2.1'
  gem.add_runtime_dependency 'bundler'
end
