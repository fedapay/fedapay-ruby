require "test_helper"

class FedaPayTest < Minitest::Test
  def test_allow_ca_bundle_path_to_be_configured
    old = FedaPay.ca_bundle_path

    FedaPay.ca_bundle_path = "path/to/ca/bundle"
    assert_equal "path/to/ca/bundle", FedaPay.ca_bundle_path

    FedaPay.ca_bundle_path = old
  end

  def test_unallow_max_network_retries_to_be_configured
    assert_raises (NoMethodError) { || old = FedaPay.max_network_retries }
  end
end
