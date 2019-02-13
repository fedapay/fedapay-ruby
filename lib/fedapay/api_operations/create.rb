# frozen_string_literal: true

module FedaPay
  module APIOperations
    module Create
      def create(params = {}, opts = {})
        resp, opts = request(:post, resource_url, params, opts)

        if self.respond_to?(:resource_object_name)
          resp = resp.data[self.resource_object_name.to_sym]
          resp = { data: resp }
        end

        Util.convert_to_fedapay_object(resp[:data], opts)
      end
    end
  end
end
