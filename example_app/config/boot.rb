WORKING_DIR = File.join(File.dirname(__FILE__), '..')
$LOAD_PATH.unshift(File.join(WORKING_DIR, 'app'))

require 'bundler'
Bundler.require

require 'securerandom'
require 'logger'
require 'smooth_queue'

require 'workers/background_worker'
require 'workers/heavy_lifting_worker'
require 'workers/very_heavy_lifting_worker'
require 'producer'
require_relative 'initializer'
