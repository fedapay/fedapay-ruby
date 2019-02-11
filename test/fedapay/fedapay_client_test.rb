# frozen_string_literal: true

require ::File.expand_path("../../test_helper", __FILE__)

module FedaPay
  class FedaPayClientTest < Minitest::Test
    def test_should_be_default_client_outside_of_request
      assert_equal FedaPayClient.default_client, FedaPayClient.active_client
    end

    def test_should_be_active_client_inside_of_request
      client = FedaPayClient.new
      client.request do
        assert_equal client, FedaPayClient.active_client
      end
    end

    def test_should_be_a_FedaPayClient
      assert_kind_of FedaPayClient, FedaPayClient.default_client
    end

    def test_should_be_a_different_client_on_each_thread
      other_thread_client = nil
      thread = Thread.new do
        other_thread_client = FedaPayClient.default_client
      end
      thread.join
      refute_equal FedaPayClient.default_client, other_thread_client
    end

    def test_should_be_a_Faraday_Connection
      assert_kind_of Faraday::Connection, FedaPayClient.default_conn
    end

    def test_should_be_a_different_connection_on_each_thread
      other_thread_conn = nil
      thread = Thread.new do
        other_thread_conn = FedaPayClient.default_conn
      end
      thread.join
      refute_equal FedaPayClient.default_conn, other_thread_conn
    end

    describe ".should_retry?" do
      before do
        FedaPay.stubs(:max_network_retries).returns(2)
      end

      def test_should_retry_on_timeout
        assert FedaPayClient.should_retry?(Faraday::TimeoutError.new(""), 0)
      end

      def test_should_retry_on_a_failed_connection
        assert FedaPayClient.should_retry?(Faraday::ConnectionFailed.new(""), 0)
      end

      def test_should_not_retry_at_maximum_count
        refute FedaPayClient.should_retry?(RuntimeError.new, FedaPay.max_network_retries)
      end

      def test_should_not_retry_on_a_certificate_validation_error
        refute FedaPayClient.should_retry?(Faraday::SSLError.new(""), 0)
      end
    end

    describe ".sleep_time" do
      def test_should_grow_exponentially
        FedaPayClient.stubs(:rand).returns(1)
        FedaPay.stubs(:max_network_retry_delay).returns(999)
        assert_equal(FedaPay.initial_network_retry_delay, FedaPayClient.sleep_time(1))
        assert_equal(FedaPay.initial_network_retry_delay * 2, FedaPayClient.sleep_time(2))
        assert_equal(FedaPay.initial_network_retry_delay * 4, FedaPayClient.sleep_time(3))
        assert_equal(FedaPay.initial_network_retry_delay * 8, FedaPayClient.sleep_time(4))
      end

      def test_enforce_the_max_network_retry_delay
        FedaPayClient.stubs(:rand).returns(1)
        FedaPay.stubs(:initial_network_retry_delay).returns(1)
        FedaPay.stubs(:max_network_retry_delay).returns(2)
        assert_equal(1, FedaPayClient.sleep_time(1))
        assert_equal(2, FedaPayClient.sleep_time(2))
        assert_equal(2, FedaPayClient.sleep_time(3))
        assert_equal(2, FedaPayClient.sleep_time(4))
      end

      def test_add_some_randomness
        random_value = 0.8
        FedaPayClient.stubs(:rand).returns(random_value)
        FedaPay.stubs(:initial_network_retry_delay).returns(1)
        FedaPay.stubs(:max_network_retry_delay).returns(8)

        base_value = FedaPay.initial_network_retry_delay * (0.5 * (1 + random_value))

        # the initial value cannot be smaller than the base,
        # so the randomness is ignored
        assert_equal(FedaPay.initial_network_retry_delay, FedaPayClient.sleep_time(1))

        # after the first one, the randomness is applied
        assert_equal(base_value * 2, FedaPayClient.sleep_time(2))
        assert_equal(base_value * 4, FedaPayClient.sleep_time(3))
        assert_equal(base_value * 8, FedaPayClient.sleep_time(4))
      end
    end

    describe "#initialize" do
      def test_set_FedaPay_default_conn
        client = FedaPayClient.new
        assert_equal FedaPayClient.default_conn, client.conn
      end

      def test_set_a_different_connection_if_one_was_specified
        conn = Faraday.new
        client = FedaPayClient.new(conn)
        assert_equal conn, client.conn
      end
    end

    describe "#execute_request" do
      before do
        FedaPay.api_base = 'https://test.fedapay.com'
      end

      describe "headers" do
        def test_support_literal_headers
          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .with(headers: { "Fedapay-Account" => "bar" })
            .to_return(body: JSON.generate(object: "account"))

          client = FedaPayClient.new
          client.execute_request(:post, "/account",
                                 headers: { "Fedapay-Account" => "bar" })
        end

        def test_support_RestClient_style_header_keys
          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .with(headers: { "Fedapay-Account" => "bar" })
            .to_return(body: JSON.generate(object: "account"))

          client = FedaPayClient.new
          client.execute_request(:post, "/account",
                                 headers: { fedapay_account: "bar" })
        end
      end

      describe "logging" do
        def test_produce_appropriate_logging
          body = JSON.generate(object: "account")

          Util.expects(:log_info).with("Request to FedaPay API",
                                       account: "acct_123",
                                       api_version: "2010-11-12",
                                       method: :post,
                                       num_retries: 0,
                                       path: "/v1/account")
          Util.expects(:log_debug).with("Request details",
                                        body: "",
                                        query_params: nil)

          Util.expects(:log_info).with("Response from FedaPay API",
                                       account: "acct_123",
                                       api_version: "2010-11-12",
                                       elapsed: 0.0,
                                       method: :post,
                                       path: "/v1/account",
                                       request_id: "req_123",
                                       status: 200)
          Util.expects(:log_debug).with("Response details",
                                        body: body,
                                        request_id: "req_123")
          Util.expects(:log_debug).with("Dashboard link for request",
                                        request_id: "req_123",
                                        url: Util.request_id_dashboard_url("req_123", FedaPay.api_key))

          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .to_return(
              body: body,
              headers: {
                "Request-Id" => "req_123",
                "Fedapay-Account" => "acct_123"
              }
            )

          client = FedaPayClient.new
          client.execute_request(:post, "/account",
                                 headers: {
                                   "Fedapay-Account" => "acct_123"
                                 })
        end

        def test_produce_logging_on_API_error
          Util.expects(:log_info).with("Request to FedaPay API",
                                       account: nil,
                                       api_version: nil,
                                       method: :post,
                                       num_retries: 0,
                                       path: "/account")
          Util.expects(:log_info).with("Response from FedaPay API",
                                       account: nil,
                                       api_version: nil,
                                       elapsed: 0.0,
                                       method: :post,
                                       path: "/account",
                                       request_id: nil,
                                       status: 500)

          error = {
            code: "code",
            message: "message",
            param: "param",
            type: "type",
          }
          Util.expects(:log_error).with("FedaPay API error",
                                        status: 500,
                                        error_code: error[:code],
                                        error_message: error[:message],
                                        error_param: error[:param],
                                        error_type: error[:type],
                                        request_id: nil)

          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .to_return(
              body: JSON.generate(error: error),
              status: 500
            )

          client = FedaPayClient.new
          assert_raises FedaPay::APIError do
            client.execute_request(:post, "/account")
          end
        end

        def test_produce_logging_on_OAuth_error
          Util.expects(:log_info).with("Request to FedaPay API",
                                       account: nil,
                                       api_version: nil,
                                       method: :post,
                                       num_retries: 0,
                                       path: "/oauth/token")
          Util.expects(:log_info).with("Response from FedaPay API",
                                       account: nil,
                                       api_version: nil,
                                       elapsed: 0.0,
                                       method: :post,
                                       path: "/oauth/token",
                                       request_id: nil,
                                       status: 400)

          Util.expects(:log_error).with("FedaPay OAuth error",
                                        status: 400,
                                        error_code: "invalid_request",
                                        error_description: "No grant type specified",
                                        request_id: nil)

          stub_request(:post, "#{FedaPay.connect_base}/oauth/token")
            .to_return(body: JSON.generate(error: "invalid_request",
                                           error_description: "No grant type specified"), status: 400)

          client = FedaPayClient.new
          opts = { api_base: FedaPay.connect_base }
          assert_raises FedaPay::OAuth::InvalidRequestError do
            client.execute_request(:post, "/oauth/token", opts)
          end
        end
      end

      after do
        FedaPay.api_base = nil
      end
    end

  end
end
