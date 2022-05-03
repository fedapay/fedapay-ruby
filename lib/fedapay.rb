# FedaPay Ruby bindings
require 'cgi'
require 'date'
require 'faraday'
require 'json'
require 'logger'
require 'openssl'
require 'active_support/inflector'

# Version
require 'fedapay/version'

# API operations
require 'fedapay/api_operations/create'
require 'fedapay/api_operations/delete'
require 'fedapay/api_operations/list'
require 'fedapay/api_operations/request'
require 'fedapay/api_operations/save'

# API resource support classes
require 'fedapay/errors'
require 'fedapay/util'
require 'fedapay/fedapay_client'
require 'fedapay/fedapay_object'
require 'fedapay/fedapay_response'
require 'fedapay/list_object'
require 'fedapay/api_resource'

# Named API resources
require 'fedapay/account'
require 'fedapay/api_key'
require 'fedapay/currency'
require 'fedapay/customer'
require 'fedapay/event'
require 'fedapay/log'
require 'fedapay/payout'
require 'fedapay/transaction'
require 'fedapay/webhook'
require 'fedapay/webhook_signature'

# Module FedaPay
module FedaPay
  DEFAULT_CA_BUNDLE_PATH = File.dirname(__FILE__) + '/data/ca-certificates.crt'

  @debug = false
  @logger = nil
  @log_level = nil
  @api_base = nil
  @api_key = nil
  @token = nil
  @account_id = nil
  @environment = 'sandbox'
  @api_version = 'v1'

  @max_network_retries = 0
  @max_network_retry_delay = 2
  @initial_network_retry_delay = 0.5

  @open_timeout = 200
  @read_timeout = 200

  @ca_store = nil
  @verify_ssl_certs = true
  @ca_bundle_path = DEFAULT_CA_BUNDLE_PATH

  @enable_telemetry = false

  LEVEL_DEBUG = Logger::DEBUG
  LEVEL_ERROR = Logger::ERROR
  LEVEL_INFO = Logger::INFO

  class << self
    attr_accessor :debug, :logger, :api_base, :api_key, :token, :account_id,
                  :environment, :api_version, :verify_ssl_certs,
                  :open_timeout, :read_timeout, :max_network_retries

    attr_reader :ca_bundle_path, :max_network_retry_delay, :initial_network_retry_delay

    def ca_bundle_path=(path)
      @ca_bundle_path = path

      # empty this field so a new store is initialized
      @ca_store = nil
    end

    def ca_store
      @ca_store ||= begin
        store = OpenSSL::X509::Store.new
        store.add_file(ca_bundle_path)
        store
      end
    end
  end

  # When set prompts the library to log some extra information to $stdout and
  # $stderr about what it's doing. For example, it'll produce information about
  # requests, responses, and errors that are received. Valid log levels are
  # `debug` and `info`, with `debug` being a little more verbose in places.
  #
  # Use of this configuration is only useful when `.logger` is _not_ set. When
  # it is, the decision what levels to print is entirely deferred to the logger.
  def self.log_level
    @log_level
  end

  def self.log_level=(val)
    # Backwards compatibility for values that we briefly allowed
    if val == 'debug'
      val = LEVEL_DEBUG
    elsif val == 'info'
      val = LEVEL_INFO
    end

    if !val.nil? && ![LEVEL_DEBUG, LEVEL_ERROR, LEVEL_INFO].include?(val)
      raise ArgumentError, 'log_level should only be set to `nil`, `debug` or `info`'
    end
    @log_level = val
  end

  # Sets a logger to which logging output will be sent. The logger should
  # support the same interface as the `Logger` class that's part of Ruby's
  # standard library (hint, anything in `Rails.logger` will likely be
  # suitable).
  #
  # If `.logger` is set, the value of `.log_level` is ignored. The decision on
  # what levels to print is entirely deferred to the logger.
  def self.logger
    @logger
  end

  def self.logger=(val)
    @logger = val
  end

  def self.max_network_retries
    @max_network_retries
  end

  def self.max_network_retries=(val)
    @max_network_retries = val.to_i
  end

  def self.enable_telemetry?
    @enable_telemetry
  end

  def self.enable_telemetry=(val)
    @enable_telemetry = val
  end
end
