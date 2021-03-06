# frozen_string_literal: true

module FedaPay
  # FedaPayResponse encapsulates some vitals of a response that came back from
  # the FedaPay API.
  class FedaPayResponse
    # The data contained by the HTTP body of the response deserialized from
    # JSON.
    attr_accessor :data

    # The raw HTTP body of the response.
    attr_accessor :http_body

    # A Hash of the HTTP headers of the response.
    attr_accessor :http_headers

    # The integer HTTP status code of the response.
    attr_accessor :http_status

    # The FedaPay request ID of the response.
    attr_accessor :request_id

    # Initializes a FedaPayResponse object from a Hash like the kind returned as
    # part of a Faraday exception.
    #
    # This may throw JSON::ParserError if the response body is not valid JSON.
    def self.from_faraday_hash(http_resp)
      resp = FedaPayResponse.new
      resp.data = JSON.parse(http_resp[:body], symbolize_names: true)
      resp.http_body = http_resp[:body]
      resp.http_headers = http_resp[:headers]
      resp.http_status = http_resp[:status]
      resp.request_id = http_resp[:headers]['Request-Id']
      resp
    end

    # Initializes a FedaPayResponse object from a Faraday HTTP response object.
    #
    # This may throw JSON::ParserError if the response body is not valid JSON.
    def self.from_faraday_response(http_resp)
      resp = FedaPayResponse.new
      resp.data = JSON.parse(http_resp.body, symbolize_names: true)
      resp.http_body = http_resp.body
      resp.http_headers = http_resp.headers
      resp.http_status = http_resp.status
      resp.request_id = http_resp.headers['Request-Id']
      resp
    end
  end
end
