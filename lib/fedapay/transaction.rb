# frozen_string_literal: true

module FedaPay
  class Transaction < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'transaction'.freeze

    @@available_mobile_money = %w[mtn moov mtn_ci]

    def generate_token
      url = "#{resource_url}/token"
      resp, opts = request(:post, url, @retrieve_params)

      Util.convert_to_fedapay_object(resp.data, opts)
    end

    def send_now_with_token(mode, token, params)
      unless mode_available(mode)
        raise ArgumentError, "Invalid payment method '#{mode}' supplied. " \
                'You have to use one of the following payment methods ' \
                "[#{@@available_mobile_money.join(', ')}]"
      end

      url = '/' + mode
      params = { token: token }.merge(params)
      resp, opts = request(:post, url, params)

      Util.convert_to_fedapay_object(resp.data, opts)
    end

    def send_now(mode, params = {})
      token_object = generate_token

      send_now_with_token(mode, token_object.token, params)
    end

    private

    def mode_available(mode)
      @@available_mobile_money.include?(mode)
    end
  end
end
