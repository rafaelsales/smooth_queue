# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = 'smooth_queue'
  gem.summary       = 'Simple Redis queue manager with flow control for Ruby apps'
  gem.description   = gem.summary
  gem.authors       = ['Rafael Sales']
  gem.email         = ['rafaelcds@gmail.com']
  gem.homepage      = 'https://github.com/rafaelsales/smooth_queue'
  gem.license       = 'MIT'
  gem.version       = '0.0.1'
  gem.executables   = ['squeue', 'smooth_queue']

  gem.add_dependency 'redis', '~> 4.0', '>= 4.0.1'
  gem.add_dependency 'connection_pool', '~> 2.2', '>= 2.2.1'
end
