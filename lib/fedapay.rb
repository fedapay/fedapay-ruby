# FedaPay Ruby bindings
require "cgi"
require "faraday"
require "json"
require "logger"
require "openssl"

# Version
require "fedapay/version"

# API operations
require "fedapay/api_operations/create"
require "fedapay/api_operations/delete"
require "fedapay/api_operations/list"
require "fedapay/api_operations/nested_resource"
require "fedapay/api_operations/request"
require "fedapay/api_operations/save"

# API resource support classes
require "fedapay/errors"
require "fedapay/util"
require "fedapay/fedapay_client"
require "fedapay/fedapay_object"
require "fedapay/api_resource"

# Named API resources
require "fedapay/customer"

# Module FedaPay
module FedaPay
  DEFAULT_CA_BUNDLE_PATH = File.dirname(__FILE__) + '/data/ca-certificates.crt'

  @debug = false
  @logger = nil
  @api_base = nil
  @api_key = nil
  @token = nil
  @account_id = nil
  @environment = 'sandbox'
  @api_version = 'v1'

  @max_network_retries = 0
  @max_network_retry_delay = 2
  @initial_network_retry_delay = 0.5

  @ca_store = nil
  @verify_ssl_certs = true
  @ca_bundle_path = DEFAULT_CA_BUNDLE_PATH

  LEVEL_DEBUG = Logger::DEBUG
  LEVEL_ERROR = Logger::ERROR
  LEVEL_INFO = Logger::INFO

  class << self
    attr_accessor :debug, :logger, :api_base, :api_key, :token, :account_id,
                  :environment, :api_version, :verify_ssl_certs
    attr_reader :ca_bundle_path

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
end
