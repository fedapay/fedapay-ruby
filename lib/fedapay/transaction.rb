# frozen_string_literal: true

module FedaPay
  class Transaction < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = 'transaction'.freeze

    def generate_token
      url = "#{resource_url}/token" 
      resp, opts = request(:post, url, @retrieve_params)

      Util.convert_to_fedapay_object(resp.data, opts)
    end
  end
end
