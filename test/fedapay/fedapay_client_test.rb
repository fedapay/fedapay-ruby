# frozen_string_literal: true

require ::File.expand_path("../../test_helper", __FILE__)

module FedaPay
  class FedaPayClientTest < Minitest::Test
    def should_be_default_client_outside_of_request
      assert_equal FedaPayClient.default_client, FedaPayClient.active_client
    end

    def should_be_active_client_inside_of_request
      client = FedaPayClient.new
      client.request do
        assert_equal client, FedaPayClient.active_client
      end
    end

    def should_be_a_FedaPayClient
      assert_kind_of FedaPayClient, FedaPayClient.default_client
    end

    def should_be_a_different_client_on_each_thread
      other_thread_client = nil
      thread = Thread.new do
        other_thread_client = FedaPayClient.default_client
      end
      thread.join
      refute_equal FedaPayClient.default_client, other_thread_client
    end

    def should_be_a_Faraday_Connection
      assert_kind_of Faraday::Connection, FedaPayClient.default_conn
    end

    def should_be_a_different_connection_on_each_thread
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

      def should_retry_on_timeout
        assert FedaPayClient.def_retry?(Faraday::TimeoutError.new(""), 0)
      end

      def should_retry_on_a_failed_connection
        assert FedaPayClient.def_retry?(Faraday::ConnectionFailed.new(""), 0)
      end

      def should_retry_on_a_conflict
        error = make_rate_limit_error
        e = Faraday::ClientError.new(error[:error][:message], status: 409)
        assert FedaPayClient.def_retry?(e, 0)
      end

      def should_not_retry_at_maximum_count
        refute FedaPayClient.def_retry?(RuntimeError.new, FedaPay.max_network_retries)
      end

      def should_not_retry_on_a_certificate_validation_error
        refute FedaPayClient.def_retry?(Faraday::SSLError.new(""), 0)
      end
    end

    def should_def_grow_exponentially
      FedaPayClient.stubs(:rand).returns(1)
      FedaPay.stubs(:max_network_retry_delay).returns(999)
      assert_equal(FedaPay.initial_network_retry_delay, FedaPayClient.sleep_time(1))
      assert_equal(FedaPay.initial_network_retry_delay * 2, FedaPayClient.sleep_time(2))
      assert_equal(FedaPay.initial_network_retry_delay * 4, FedaPayClient.sleep_time(3))
      assert_equal(FedaPay.initial_network_retry_delay * 8, FedaPayClient.sleep_time(4))
    end

    def should_enforce_the_max_network_retry_delay
      FedaPayClient.stubs(:rand).returns(1)
      FedaPay.stubs(:initial_network_retry_delay).returns(1)
      FedaPay.stubs(:max_network_retry_delay).returns(2)
      assert_equal(1, FedaPayClient.sleep_time(1))
      assert_equal(2, FedaPayClient.sleep_time(2))
      assert_equal(2, FedaPayClient.sleep_time(3))
      assert_equal(2, FedaPayClient.sleep_time(4))
    end

    def should_add_some_randomnessshould_
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

    def should_set_FedaPay_default_conn
      client = FedaPayClient.new
      assert_equal FedaPayClient.default_conn, client.conn
    end

    def should_set_a_different_connection_if_one_was_specified
      conn = Faraday.new
      client = FedaPayClient.new(conn)
      assert_equal conn, client.conn
    end

    def should_support_literal_headers
      stub_request(:post, "#{FedaPay.api_base}/v1/account")
        .with(headers: { "FedaPay-Account" => "bar" })
        .to_return(body: JSON.generate(object: "account"))

      client = FedaPayClient.new
      client.execute_request(:post, "/v1/account",
                              headers: { "FedaPay-Account" => "bar" })
    end

    def should_support_RestClient_style_header_keys
      stub_request(:post, "#{FedaPay.api_base}/v1/account")
        .with(headers: { "FedaPay-Account" => "bar" })
        .to_return(body: JSON.generate(object: "account"))

      client = FedaPayClient.new
      client.execute_request(:post, "/v1/account",
                              headers: { stripe_account: "bar" })
    end

    describe "logging" do
      before do
        # Freeze time for the purposes of the `elapsed` parameter that we
        # emit for responses. I didn't want to bring in a new dependency for
        # this, but Mocha's `anything` parameter can't match inside of a hash
        # and is therefore not useful for this purpose. If we switch over to
        # rspec-mocks at some point, we can probably remove Timecop from the
        # project.
        Timecop.freeze(Time.local(1990))
      end

      after do
        Timecop.return
      end

      def should_produce_appropriate_logging
        body = JSON.generate(object: "account")

        Util.expects(:log_info).with("Request to FedaPay API",
                                      account: "acct_123",
                                      api_version: "2010-11-12",
                                      idempotency_key: "abc",
                                      method: :post,
                                      num_retries: 0,
                                      path: "/v1/account")
        Util.expects(:log_debug).with("Request details",
                                      body: "",
                                      idempotency_key: "abc",
                                      query_params: nil)

        Util.expects(:log_info).with("Response from FedaPay API",
                                      account: "acct_123",
                                      api_version: "2010-11-12",
                                      elapsed: 0.0,
                                      idempotency_key: "abc",
                                      method: :post,
                                      path: "/v1/account",
                                      request_id: "req_123",
                                      status: 200)
        Util.expects(:log_debug).with("Response details",
                                      body: body,
                                      idempotency_key: "abc",
                                      request_id: "req_123")
        Util.expects(:log_debug).with("Dashboard link for request",
                                      idempotency_key: "abc",
                                      request_id: "req_123",
                                      url: Util.request_id_dashboard_url("req_123", FedaPay.api_key))

        stub_request(:post, "#{FedaPay.api_base}/v1/account")
          .to_return(
            body: body,
            headers: {
              "Idempotency-Key" => "abc",
              "Request-Id" => "req_123",
              "FedaPay-Account" => "acct_123",
              "FedaPay-Version" => "2010-11-12",
            }
          )

        client = FedaPayClient.new
        client.execute_request(:post, "/v1/account",
                                headers: {
                                  "Idempotency-Key" => "abc",
                                  "FedaPay-Account" => "acct_123",
                                  "FedaPay-Version" => "2010-11-12",
                                })
      end

      def should_produce_logging_on_API_error
        Util.expects(:log_info).with("Request to FedaPay API",
                                      account: nil,
                                      api_version: nil,
                                      idempotency_key: nil,
                                      method: :post,
                                      num_retries: 0,
                                      path: "/v1/account")
        Util.expects(:log_info).with("Response from FedaPay API",
                                      account: nil,
                                      api_version: nil,
                                      elapsed: 0.0,
                                      idempotency_key: nil,
                                      method: :post,
                                      path: "/v1/account",
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
                                      idempotency_key: nil,
                                      request_id: nil)

        stub_request(:post, "#{FedaPay.api_base}/v1/account")
          .to_return(
            body: JSON.generate(error: error),
            status: 500
          )

        client = FedaPayClient.new
        assert_raises FedaPay::APIError do
          client.execute_request(:post, "/v1/account")
        end
      end

      def should_produce_logging_on_OAuth_error
        Util.expects(:log_info).with("Request to FedaPay API",
                                      account: nil,
                                      api_version: nil,
                                      idempotency_key: nil,
                                      method: :post,
                                      num_retries: 0,
                                      path: "/oauth/token")
        Util.expects(:log_info).with("Response from FedaPay API",
                                      account: nil,
                                      api_version: nil,
                                      elapsed: 0.0,
                                      idempotency_key: nil,
                                      method: :post,
                                      path: "/oauth/token",
                                      request_id: nil,
                                      status: 400)

        Util.expects(:log_error).with("FedaPay OAuth error",
                                      status: 400,
                                      error_code: "invalid_request",
                                      error_description: "No grant type specified",
                                      idempotency_key: nil,
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

    describe "FedaPay-Account header" do
      def should_use_a_globally_set_header
        begin
          old = FedaPay.stripe_account
          FedaPay.stripe_account = "acct_1234"

          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .with(headers: { "FedaPay-Account" => FedaPay.stripe_account })
            .to_return(body: JSON.generate(object: "account"))

          client = FedaPayClient.new
          client.execute_request(:post, "/v1/account")
        ensure
          FedaPay.stripe_account = old
        end
      end

      def should_use_a_locally_set_header
        stripe_account = "acct_0000"
        stub_request(:post, "#{FedaPay.api_base}/v1/account")
          .with(headers: { "FedaPay-Account" => stripe_account })
          .to_return(body: JSON.generate(object: "account"))

        client = FedaPayClient.new
        client.execute_request(:post, "/v1/account",
                                headers: { stripe_account: stripe_account })
      end

      def should_not_send_it_otherwise
        stub_request(:post, "#{FedaPay.api_base}/v1/account")
          .with do |req|
            req.headers["FedaPay-Account"].nil?
          end.to_return(body: JSON.generate(object: "account"))

        client = FedaPayClient.new
        client.execute_request(:post, "/v1/account")
      end
    end

    describe "app_info" do
      def should_send_app_info_if_set
        begin
          old = FedaPay.app_info
          FedaPay.set_app_info(
            "MyAwesomePlugin",
            partner_id: "partner_1234",
            url: "https://myawesomeplugin.info",
            version: "1.2.34"
          )

          stub_request(:post, "#{FedaPay.api_base}/v1/account")
            .with do |req|
              assert_equal \
                "FedaPay/v1 RubyBindings/#{FedaPay::VERSION} " \
                "MyAwesomePlugin/1.2.34 (https://myawesomeplugin.info)",
                req.headers["User-Agent"]

              data = JSON.parse(req.headers["X-FedaPay-Client-User-Agent"],
                                symbolize_names: true)

              assert_equal({
                name: "MyAwesomePlugin",
                partner_id: "partner_1234",
                url: "https://myawesomeplugin.info",
                version: "1.2.34",
              }, data[:application])

              true
            end.to_return(body: JSON.generate(object: "account"))

          client = FedaPayClient.new
          client.execute_request(:post, "/v1/account")
        ensure
          FedaPay.app_info = old
        end
      end
    end

    describe "should error handling" do
      def handle_error_response_with_empty_body
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: "", status: 500)

        client = FedaPayClient.new
        e = assert_raises FedaPay::APIError do
          client.execute_request(:post, "/v1/charges")
        end

        assert_equal 'Invalid response object from API: "" (HTTP response code was 500)', e.message
      end

      def should_handle_success_response_with_empty_body
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: "", status: 200)

        client = FedaPayClient.new
        e = assert_raises FedaPay::APIError do
          client.execute_request(:post, "/v1/charges")
        end

        assert_equal 'Invalid response object from API: "" (HTTP response code was 200)', e.message
      end

      def should_handle_error_response_with_unknown_value
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(bar: "foo"), status: 500)

        client = FedaPayClient.new
        e = assert_raises FedaPay::APIError do
          client.execute_request(:post, "/v1/charges")
        end

        assert_equal 'Invalid response object from API: "{\"bar\":\"foo\"}" (HTTP response code was 500)', e.message
      end

      def should_raise_IdempotencyError_on_400_of_type_idempotency_error
        data = make_missing_id_error
        data[:error][:type] = "idempotency_error"

        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(data), status: 400)
        client = FedaPayClient.new

        e = assert_raises FedaPay::IdempotencyError do
          client.execute_request(:post, "/v1/charges")
        end
        assert_equal(400, e.http_status)
        assert_equal(true, e.json_body.is_a?(Hash))
      end

      def should_raise_InvalidRequestError_on_other_400s
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_missing_id_error), status: 400)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::InvalidRequestError => e
          assert_equal(400, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
        end
      end

      def should_raise_AuthenticationError_on_401
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_missing_id_error), status: 401)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::AuthenticationError => e
          assert_equal(401, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
        end
      end

      def should_raise_CardError_on_402
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_invalid_exp_year_error), status: 402)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::CardError => e
          assert_equal(402, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
          assert_equal("invalid_expiry_year", e.code)
          assert_equal("exp_year", e.param)
        end
      end

      def should_raise_PermissionError_on_403
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_missing_id_error), status: 403)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::PermissionError => e
          assert_equal(403, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
        end
      end

      def should_raise_InvalidRequestError_on_404
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_missing_id_error), status: 404)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::InvalidRequestError => e
          assert_equal(404, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
        end
      end

      def should_raise_RateLimitError_on_429
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(make_rate_limit_error), status: 429)
        client = FedaPayClient.new
        begin
          client.execute_request(:post, "/v1/charges")
        rescue FedaPay::RateLimitError => e
          assert_equal(429, e.http_status)
          assert_equal(true, e.json_body.is_a?(Hash))
        end
      end

      def should_raise_OAuth_InvalidRequestError
        stub_request(:post, "#{FedaPay.connect_base}/oauth/token")
          .to_return(body: JSON.generate(error: "invalid_request",
                                          error_description: "No grant type specified"), status: 400)

        client = FedaPayClient.new
        opts = { api_base: FedaPay.connect_base }
        e = assert_raises FedaPay::OAuth::InvalidRequestError do
          client.execute_request(:post, "/oauth/token", opts)
        end

        assert_equal(400, e.http_status)
        assert_equal("No grant type specified", e.message)
      end

      def should_raise_OAuth_InvalidGrantError
        stub_request(:post, "#{FedaPay.connect_base}/oauth/token")
          .to_return(body: JSON.generate(error: "invalid_grant",
                                          error_description: "This authorization code has already been used. All tokens issued with this code have been revoked."), status: 400)

        client = FedaPayClient.new
        opts = { api_base: FedaPay.connect_base }
        e = assert_raises FedaPay::OAuth::InvalidGrantError do
          client.execute_request(:post, "/oauth/token", opts)
        end

        assert_equal(400, e.http_status)
        assert_equal("invalid_grant", e.code)
        assert_equal("This authorization code has already been used. All tokens issued with this code have been revoked.", e.message)
      end

      def should_raise_OAuth_InvalidClientError
        stub_request(:post, "#{FedaPay.connect_base}/oauth/deauthorize")
          .to_return(body: JSON.generate(error: "invalid_client",
                                          error_description: "This application is not connected to stripe account acct_19tLK7DSlTMT26Mk, or that account does not exist."), status: 401)

        client = FedaPayClient.new
        opts = { api_base: FedaPay.connect_base }
        e = assert_raises FedaPay::OAuth::InvalidClientError do
          client.execute_request(:post, "/oauth/deauthorize", opts)
        end

        assert_equal(401, e.http_status)
        assert_equal("invalid_client", e.code)
        assert_equal("This application is not connected to stripe account acct_19tLK7DSlTMT26Mk, or that account does not exist.", e.message)
      end

      def should_raise_FedaPay_OAuthError_on_indeterminate_OAuth_error
        stub_request(:post, "#{FedaPay.connect_base}/oauth/deauthorize")
          .to_return(body: JSON.generate(error: "new_code_not_recognized",
                                          error_description: "Something."), status: 401)

        client = FedaPayClient.new
        opts = { api_base: FedaPay.connect_base }
        e = assert_raises FedaPay::OAuth::OAuthError do
          client.execute_request(:post, "/oauth/deauthorize", opts)
        end

        assert_equal(401, e.http_status)
        assert_equal("new_code_not_recognized", e.code)
        assert_equal("Something.", e.message)
      end
    end

    describe "idempotency keys" do
      before do
        FedaPay.stubs(:max_network_retries).returns(2)
      end

      def should_not_add_an_idempotency_key_to_GET_requests
        SecureRandom.expects(:uuid).times(0)
        stub_request(:get, "#{FedaPay.api_base}/v1/charges/ch_123")
          .with do |req|
            req.headers["Idempotency-Key"].nil?
          end.to_return(body: JSON.generate(object: "charge"))
        client = FedaPayClient.new
        client.execute_request(:get, "/v1/charges/ch_123")
      end

      def should_ensure_there_is_always_an_idempotency_key_on_POST_requests
        SecureRandom.expects(:uuid).at_least_once.returns("random_key")
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .with(headers: { "Idempotency-Key" => "random_key" })
          .to_return(body: JSON.generate(object: "charge"))
        client = FedaPayClient.new
        client.execute_request(:post, "/v1/charges")
      end

      def should_ensure_there_is_always_an_idempotency_key_on_DELETE_requests
        SecureRandom.expects(:uuid).at_least_once.returns("random_key")
        stub_request(:delete, "#{FedaPay.api_base}/v1/charges/ch_123")
          .with(headers: { "Idempotency-Key" => "random_key" })
          .to_return(body: JSON.generate(object: "charge"))
        client = FedaPayClient.new
        client.execute_request(:delete, "/v1/charges/ch_123")
      end

      def should_not_override_a_provided_idempotency_key
        # Note that this expectation looks like `:idempotency_key` instead of
        # the header `Idempotency-Key` because it's user provided as seen
        # below. The ones injected by the library itself look like headers
        # (`Idempotency-Key`), but rest-client does allow this symbol
        # formatting and will properly override the system generated one as
        # expected.
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .with(headers: { "Idempotency-Key" => "provided_key" })
          .to_return(body: JSON.generate(object: "charge"))

        client = FedaPayClient.new
        client.execute_request(:post, "/v1/charges",
                                headers: { idempotency_key: "provided_key" })
      end
    end

    describe "retry logic" do
      before do
        FedaPay.stubs(:max_network_retries).returns(2)
      end

      def should_retry_failed_requests_and_raise_if_error_persists
        FedaPayClient.expects(:sleep_time).at_least_once.returns(0)
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_raise(Errno::ECONNREFUSED.new)

        client = FedaPayClient.new
        err = assert_raises FedaPay::APIConnectionError do
          client.execute_request(:post, "/v1/charges")
        end
        assert_match(/Request was retried 2 times/, err.message)
      end

      def should_retry_failed_requests_and_return_successful_response
        FedaPayClient.expects(:sleep_time).at_least_once.returns(0)

        i = 0
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return do |_|
            if i < 2
              i += 1
              raise Errno::ECONNREFUSED
            else
              { body: JSON.generate("id" => "myid") }
            end
          end

        client = FedaPayClient.new
        client.execute_request(:post, "/v1/charges")
      end
    end

    describe "params serialization" do
      def should_allows_empty_strings_in_params
        client = FedaPayClient.new
        client.execute_request(:get, "/v1/invoices/upcoming", params: {
          customer: "cus_123",
          coupon: "",
        })
        assert_requested(
          :get,
          "#{FedaPay.api_base}/v1/invoices/upcoming?",
          query: {
            customer: "cus_123",
            coupon: "",
          }
        )
      end

      def should_filter_nils_in_params
        client = FedaPayClient.new
        client.execute_request(:get, "/v1/invoices/upcoming", params: {
          customer: "cus_123",
          coupon: nil,
        })
        assert_requested(
          :get,
          "#{FedaPay.api_base}/v1/invoices/upcoming?",
          query: {
            customer: "cus_123",
          }
        )
      end

      def should_merge_query_parameters_in_URL_and_params
        client = FedaPayClient.new
        client.execute_request(:get, "/v1/invoices/upcoming?coupon=25OFF", params: {
          customer: "cus_123",
        })
        assert_requested(
          :get,
          "#{FedaPay.api_base}/v1/invoices/upcoming?",
          query: {
            coupon: "25OFF",
            customer: "cus_123",
          }
        )
      end

      def should_prefer_query_parameters_in_params
        client = FedaPayClient.new
        client.execute_request(:get, "/v1/invoices/upcoming?customer=cus_query", params: {
          customer: "cus_param",
        })
        assert_requested(
          :get,
          "#{FedaPay.api_base}/v1/invoices/upcoming?",
          query: {
            customer: "cus_param",
          }
        )
      end
    end

    describe "#request" do
      def should_return_a_result_and_response_object
        stub_request(:post, "#{FedaPay.api_base}/v1/charges")
          .to_return(body: JSON.generate(object: "charge"))

        client = FedaPayClient.new
        charge, resp = client.request { Charge.create }

        assert charge.is_a?(Charge)
        assert resp.is_a?(FedaPayResponse)
        assert_equal 200, resp.http_status
      end

      def should_return_the_value_of_given_block
        client = FedaPayClient.new
        ret, = client.request { 7 }
        assert_equal 7, ret
      end

      def should_reset_local_thread_state_after_a_call
        begin
          Thread.current[:stripe_client] = :stripe_client

          client = FedaPayClient.new
          client.request {}

          assert_equal :stripe_client, Thread.current[:stripe_client]
        ensure
          Thread.current[:stripe_client] = nil
        end
      end
    end

    describe "#telemetry" do
      after do
        # make sure to always set telemetry back to false
        # to not mutate global state
        FedaPay.enable_telemetry = false
      end

      def should_not_send_metrics_if_enable_trace_flag_is_not_set
        FedaPay.enable_telemetry = false

        trace_metrics_header = nil
        stub_request(:get, "#{FedaPay.api_base}/v1/charges")
          .with do |req|
          trace_metrics_header = req.headers["X-FedaPay-Client-Telemetry"]
          false
        end.to_return(body: JSON.generate(object: "charge"))

        FedaPay::Charge.list
        assert(trace_metrics_header.nil?)

        FedaPay::Charge.list
        assert(trace_metrics_header.nil?)
      end

      def should_send_metrics_if_enabled_telemetry_is_true
        FedaPay.enable_telemetry = true

        trace_metrics_header = nil
        stub_request(:get, "#{FedaPay.api_base}/v1/charges")
          .with do |req|
          trace_metrics_header = req.headers["X-FedaPay-Client-Telemetry"]
          false
        end.to_return(body: JSON.generate(object: "charge"))

        FedaPay::Charge.list
        FedaPay::Charge.list

        assert(!trace_metrics_header.nil?)

        trace_payload = JSON.parse(trace_metrics_header)
        assert(trace_payload["last_request_metrics"]["request_id"] == "req_123")
        assert(!trace_payload["last_request_metrics"]["request_duration_ms"].nil?)
      end
    end

    describe "#uname" do
      def should_run_without_failure
        # Don't actually check the result because we try a variety of different
        # strategies that will have different results depending on where this
        # test and running. We're mostly making sure that no exception is thrown.
        _ = FedaPayClient::SystemProfiler.uname
      end
    end

    describe "#uname_from_system" do
      def should_run_without_failure
        # as above, just verify that an exception is not thrown
        _ = FedaPayClient::SystemProfiler.uname_from_system
      end
    end

    describe "#uname_from_system_ver" do
      def should_run_without_failure
        # as above, just verify that an exception is not thrown
        _ = FedaPayClient::SystemProfiler.uname_from_system_ver
      end
    end
  end
end
