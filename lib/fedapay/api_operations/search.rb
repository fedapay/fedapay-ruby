# frozen_string_literal: true

module FedaPay
  module APIOperations
    module Search
      def search(filters = {}, opts = {})
        opts = Util.normalize_opts(opts)
        url = "#{resource_url}/search"
        resp, opts = request(:get, url, filters, opts)

        if self.respond_to?(:resource_object_name)
          resp = resp.data[self.resource_object_name.pluralize.to_sym]
          resp = { data: { data: resp} }
        end

        obj = ListObject.construct_from(resp[:data], opts)

        # set filters so that we can fetch the same limit, expansions, and
        # predicates when accessing the next and previous pages
        #
        # just for general cleanliness, remove any paging options
        obj.filters = filters.dup
        obj.filters.delete(:ending_before)
        obj.filters.delete(:starting_after)

        obj
      end
    end
  end
end
