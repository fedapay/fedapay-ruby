module FedaPay
  class Page < APIResource
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::Create
    extend FedaPay::APIOperations::Delete
    extend FedaPay::APIOperations::Save

    def verify(id, params = {}, opts = {})
      url = "#{resource_url}/verify"
      resp, opts = request(:get, url, params, opts)

      Util.convert_to_fedapay_object(resp.data, opts)
    end
  end
end