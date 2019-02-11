$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "fedapay"

gem 'mocha'
require "minitest/autorun"
require "minitest/reporters"
require "mocha/setup"
require 'webmock/minitest'

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new
