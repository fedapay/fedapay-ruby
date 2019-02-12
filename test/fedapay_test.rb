require 'test_helper'

class FedaPayTest < Minitest::Test
  def test_allow_ca_bundle_path_to_be_configured
    old = FedaPay.ca_bundle_path

    FedaPay.ca_bundle_path = 'path/to/ca/bundle'
    assert_equal 'path/to/ca/bundle', FedaPay.ca_bundle_path

    FedaPay.ca_bundle_path = old
  end

  def test_allow_max_network_retries_to_be_configured
    old = FedaPay.max_network_retries
    FedaPay.max_network_retries = 99
    assert_equal 99, FedaPay.max_network_retries
  ensure
    FedaPay.max_network_retries = old
  end
end
