# frozen_string_literal: true

module FedaPay
  # FedaPayClient executes requests against the FedaPay API and allows a user to
  # recover both a resource a call returns as well as a response object that
  # contains information on the HTTP call.
  class FedaPayClient
    attr_accessor :conn

    SANDBOX_BASE = 'https://sandbox-api.fedapay.com'.freeze

    PRODUCTION_BASE = 'https://api.fedapay.com'.freeze

    # Initializes a new FedaPayClient. Expects a Faraday connection object, and
    # uses a default connection unless one is passed.
    def initialize(conn = nil)
      @conn = conn || self.class.default_conn
    end

    def self.active_client
      Thread.current[:fedapay_client] || default_client
    end

    def self.default_client
      Thread.current[:fedapay_client_default_client] ||= FedaPayClient.new(default_conn)
    end

    # A default Faraday connection to be used when one isn't configured. This
    # object should never be mutated, and instead instantiating your own
    # connection and wrapping it in a FedaPayClient object should be preferred.
    def self.default_conn
      # We're going to keep connections around so that we can take advantage
      # of connection re-use, so make sure that we have a separate connection
      # object per thread.
      Thread.current[:fedapay_client_default_conn] ||= begin
        conn = Faraday.new do |c|
          c.use Faraday::Request::Multipart
          c.use Faraday::Request::UrlEncoded
          c.use Faraday::Response::RaiseError
          c.adapter Faraday.default_adapter
        end

        if FedaPay.verify_ssl_certs
          conn.ssl.verify = true
          conn.ssl.cert_store = FedaPay.ca_store
        else
          conn.ssl.verify = false

          unless @verify_ssl_warned
            @verify_ssl_warned = true
            warn('WARNING: Running without SSL cert verification. ' \
              'You should never do this in production. ' \
              "Execute 'FedaPay.verify_ssl_certs = true' to enable verification.")
          end
        end

        conn
      end
    end

    # Checks if an error is a problem that we should retry on. This includes both
    # socket errors that may represent an intermittent problem and some special
    # HTTP statuses.
    def self.should_retry?(e, num_retries)
      return false if num_retries >= FedaPay.max_network_retries

      # Retry on timeout-related problems (either on open or read).
      return true if e.is_a?(Faraday::TimeoutError)

      # Destination refused the connection, the connection was reset, or a
      # variety of other connection failures. This could occur from a single
      # saturated server, so retry in case it's intermittent.
      return true if e.is_a?(Faraday::ConnectionFailed)

      if e.is_a?(Faraday::ClientError) && e.response
        # 409 conflict
        return true if e.response[:status] == 409
      end

      false
    end

    def self.sleep_time(num_retries)
      # Apply exponential backoff with initial_network_retry_delay on the
      # number of num_retries so far as inputs. Do not allow the number to exceed
      # max_network_retry_delay.
      sleep_seconds = [FedaPay.initial_network_retry_delay * (2**(num_retries - 1)), FedaPay.max_network_retry_delay].min

      # Apply some jitter by randomizing the value in the range of (sleep_seconds
      # / 2) to (sleep_seconds).
      sleep_seconds *= (0.5 * (1 + rand))

      # But never sleep less than the base sleep seconds.
      sleep_seconds = [FedaPay.initial_network_retry_delay, sleep_seconds].max

      sleep_seconds
    end

    # Executes the API call within the given block. Usage looks like:
    #
    #     client = FedaPayClient.new
    #     charge, resp = client.request { Charge.create }
    #
    def request
      @last_response = nil
      old_fedapay_client = Thread.current[:fedapay_client]
      Thread.current[:fedapay_client] = self

      begin
        res = yield
        [res, @last_response]
      ensure
        Thread.current[:fedapay_client] = old_fedapay_client
      end
    end

    def execute_request(method, path, api_base: nil, api_key: nil,
                        params: {}, headers: {})

      FedaPay.api_base = api_base if api_base
      FedaPay.api_key = api_key if api_key

      params = Util.objects_to_ids(params)
      url = api_url(path)

      body = nil
      query_params = nil

      case method.to_s.downcase.to_sym
      when :get, :head, :delete
        query_params = params
      else
        body = Util.encode_parameters(params)
      end

      # This works around an edge case where we end up with both query
      # parameters in `query_params` and query parameters that are appended
      # onto the end of the given path. In this case, Faraday will silently
      # discard the URL's parameters which may break a request.
      #
      # Here we decode any parameters that were added onto the end of a path
      # and add them to `query_params` so that all parameters end up in one
      # place and all of them are correctly included in the final request.
      u = URI.parse(path)
      unless u.query.nil?
        query_params ||= {}
        query_params = Hash[URI.decode_www_form(u.query)].merge(query_params)

        # Reset the path minus any query parameters that were specified.
        path = u.path
      end

      api_key = FedaPay.api_key || FedaPay.token

      headers = headers.merge(default_headers)

      # stores information on the request we're about to make so that we don't
      # have to pass as many parameters around for logging.
      context = RequestLogContext.new
      context.account         = headers['Fedapay-Account']
      context.api_key         = api_key
      context.api_version     = headers['X-Api-Version']
      context.idempotency_key = headers['Idempotency-Key']
      context.body            = body
      context.method          = method
      context.path            = path
      context.url             = url
      context.query_params    = query_params ? Util.encode_parameters(query_params) : nil

      http_resp = execute_request_with_rescues(context) do
        conn.run_request(method, url, body, headers) do |req|
          req.options.open_timeout = FedaPay.open_timeout
          req.options.timeout = FedaPay.read_timeout
          req.params = query_params unless query_params.nil?
        end
      end

      begin
        resp = FedaPayResponse.from_faraday_response(http_resp)
      rescue JSON::ParserError
        raise general_api_error(http_resp.status, http_resp.body)
      end

      # Allows FedaPayClient#request to return a response object to a caller.
      @last_response = resp
      [resp, api_key]
    end

    private

    def base_url
      api_base = FedaPay.api_base
      environment = FedaPay.environment

      return api_base if api_base

      case environment
      when 'development', 'sandbox', 'test', nil
        SANDBOX_BASE
      when 'production', 'live'
        PRODUCTION_BASE
      end
    end

    def api_url(path = '')
      base_url + '/' + FedaPay.api_version + path
    end

    def execute_request_with_rescues(context)
      num_retries = 0
      begin
        request_start = Time.now
        log_request(context, num_retries)
        resp = yield
        context = context.dup_from_response(resp)
        log_response(context, request_start, resp.status, resp.body)

        if FedaPay.enable_telemetry? && context.request_id
          request_duration_ms = ((Time.now - request_start) * 1000).to_int
          @last_request_metrics = FedaPayRequestMetrics.new(context.request_id, request_duration_ms)
        end

      # We rescue all exceptions from a request so that we have an easy spot to
      # implement our retry logic across the board. We'll re-raise if it's a type
      # of exception that we didn't expect to handle.
      rescue StandardError => e
        # If we modify context we copy it into a new variable so as not to
        # taint the original on a retry.
        error_context = context

        if e.respond_to?(:response) && e.response
          error_context = context.dup_from_response(e.response)
          log_response(error_context, request_start,
                       e.response[:status], e.response[:body])
        else
          log_response_error(error_context, request_start, e)
        end

        if self.class.should_retry?(e, num_retries)
          num_retries += 1
          sleep self.class.sleep_time(num_retries)
          retry
        end

        case e
        when Faraday::ClientError
          if e.response
            handle_error_response(e.response)
          else
            handle_network_error(e, num_retries)
          end

        # Only handle errors when we know we can do so, and re-raise otherwise.
        # This should be pretty infrequent.
        else
          raise
        end
      end

      resp
    end

    def general_api_error(status, body)
      APIError.new("Invalid response object from API: #{body.inspect} " \
                   "(HTTP response code was #{status})",
                   http_status: status, http_body: body)
    end

    def handle_error_response(http_resp)
      begin
        resp = FedaPayResponse.from_faraday_hash(http_resp)
        error_data = resp.data[:error]

        raise FedaPayError, 'Indeterminate error' unless error_data
      rescue JSON::ParserError, FedaPayError
        raise general_api_error(http_resp[:status], http_resp[:body])
      end

      error = specific_api_error(resp, error_data)
      error.response = resp

      raise(error)
    end

    def specific_api_error(resp, error_data)
      # The standard set of arguments that can be used to initialize most of
      # the exceptions.
      opts = {
        http_body: resp.http_body,
        http_headers: resp.http_headers,
        http_status: resp.http_status,
        json_body: resp.data,
        code: error_data[:code]
      }

      case resp.http_status
      when 400, 404
        InvalidRequestError.new(
          error_data[:message], error_data[:param],
          opts
        )
      when 401
        AuthenticationError.new(error_data[:message], opts)
      else
        APIError.new(error_data[:message], opts)
      end
    end

    def handle_network_error(e, num_retries)
      Util.log_error('FedaPay network error', error_message: e.message)

      case e
      when Faraday::ConnectionFailed
        message = 'Unexpected error communicating when trying to connect to FedaPay. ' \
          'You may be seeing this message because your DNS is not working. ' \
          "To check, try running 'host fedapay.com' from the command line."

      when Faraday::SSLError
        message = 'Could not establish a secure connection to FedaPay, you may ' \
                  'need to upgrade your OpenSSL version. To check, try running ' \
                  "'openssl s_client -connect api.fedapay.com:443' from the " \
                  'command line.'

      when Faraday::TimeoutError
        message = "Could not connect to FedaPay (#{FedaPay.api_base}). " \
          'Please check your internet connection and try again. ' \
          "If this problem persists, you should check FedaPay's service status at " \
          'https://twitter.com/fedapaystatus, or let us know at support@fedapay.com.'

      else
        message = 'Unexpected error communicating with FedaPay. ' \
          'If this problem persists, let us know at support@fedapay.com.'

      end

      message += " Request was retried #{num_retries} times." if num_retries > 0

      raise APIConnectionError, message + "\n\n(Network error: #{e.message})"
    end

    def default_headers
      headers = {
        'X-Version' => FedaPay::VERSION,
        'X-Api-Version' => FedaPay.api_version,
        'X-Source' => 'FedaPay RubyLib',
        'Authorization' => "Bearer #{FedaPay.api_key || FedaPay.token}"
      }

      headers['Fedapay-Account'] = FedaPay.account_id if FedaPay.account_id

      headers
    end

    def log_request(context, num_retries)
      Util.log_info('Request to FedaPay API',
                    account: context.account,
                    api_version: context.api_version,
                    method: context.method,
                    num_retries: num_retries,
                    url: context.url,
                    path: context.path)
      Util.log_debug('Request details',
                     body: context.body,
                     query_params: context.query_params)
    end

    def log_response(context, request_start, status, body)
      Util.log_info('Response from FedaPay API',
                    account: context.account,
                    api_version: context.api_version,
                    elapsed: Time.now - request_start,
                    method: context.method,
                    path: context.path,
                    request_id: context.request_id,
                    status: status)
      Util.log_debug('Response details',
                     body: body,
                     request_id: context.request_id)

      return unless context.request_id

      Util.log_debug('Dashboard link for request',
                     request_id: context.request_id,
                     url: Util.request_id_dashboard_url(context.request_id, context.api_key))
    end

    def log_response_error(context, request_start, e)
      Util.log_error('Request error',
                     elapsed: Time.now - request_start,
                     error_message: e.message,
                     method: context.method,
                     path: context.path)
    end

    # RequestLogContext stores information about a request that's begin made so
    # that we can log certain information. It's useful because it means that we
    # don't have to pass around as many parameters.
    class RequestLogContext
      attr_accessor :body
      attr_accessor :account
      attr_accessor :api_key
      attr_accessor :api_version
      attr_accessor :idempotency_key
      attr_accessor :method
      attr_accessor :path
      attr_accessor :url
      attr_accessor :query_params
      attr_accessor :request_id

      # The idea with this method is that we might want to update some of
      # context information because a response that we've received from the API
      # contains information that's more authoritative than what we started
      # with for a request. For example, we should trust whatever came back in
      # a `FedaPay-Version` header beyond what configuration information that we
      # might have had available.
      def dup_from_response(resp)
        return self if resp.nil?

        # Faraday's API is a little unusual. Normally it'll produce a response
        # object with a `headers` method, but on error what it puts into
        # `e.response` is an untyped `Hash`.
        headers = if resp.is_a?(Faraday::Response)
                    resp.headers
                  else
                    resp[:headers]
                  end

        context = dup
        context.account = headers['Fedapay-Account']
        context.api_version = headers['X-Api-Version']
        context.idempotency_key = headers['Idempotency-Key']
        context.request_id = headers['Request-Id']
        context
      end
    end

    # SystemProfiler extracts information about the system that we're running
    # in so that we can generate a rich user agent header to help debug
    # integrations.
    class SystemProfiler
      def self.uname
        if ::File.exist?('/proc/version')
          ::File.read('/proc/version').strip
        else
          case RbConfig::CONFIG['host_os']
          when /linux|darwin|bsd|sunos|solaris|cygwin/i
            uname_from_system
          when /mswin|mingw/i
            uname_from_system_ver
          else
            'unknown platform'
          end
        end
      end

      def self.uname_from_system
        (`uname -a 2>/dev/null` || '').strip
      rescue Errno::ENOENT
        'uname executable not found'
      rescue Errno::ENOMEM # couldn't create subprocess
        'uname lookup failed'
      end

      def self.uname_from_system_ver
        (`ver` || '').strip
      rescue Errno::ENOENT
        'ver executable not found'
      rescue Errno::ENOMEM # couldn't create subprocess
        'uname lookup failed'
      end

      def initialize
        @uname = self.class.uname
      end

      def user_agent
        lang_version = "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})"

        {
          application: FedaPay.app_info,
          bindings_version: FedaPay::VERSION,
          lang: 'ruby',
          lang_version: lang_version,
          platform: RUBY_PLATFORM,
          engine: defined?(RUBY_ENGINE) ? RUBY_ENGINE : '',
          publisher: 'fedapay',
          uname: @uname,
          hostname: Socket.gethostname
        }.delete_if { |_k, v| v.nil? }
      end
    end

    # FedaPayRequestMetrics tracks metadata to be reported to stripe for metrics collection
    class FedaPayRequestMetrics
      # The FedaPay request ID of the response.
      attr_accessor :request_id

      # Request duration in milliseconds
      attr_accessor :request_duration_ms

      def initialize(request_id, request_duration_ms)
        self.request_id = request_id
        self.request_duration_ms = request_duration_ms
      end

      def payload
        { request_id: request_id, request_duration_ms: request_duration_ms }
      end
    end
  end
end
