$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'fedapay'

gem 'mocha'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest-spec-context'
require 'mocha/setup'
require 'timecop'
require 'webmock/minitest'

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
