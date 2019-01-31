# frozen_string_literal: true

module FedaPay
  class Customer < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = "customer".freeze

    save_nested_resource :source
    nested_resource_class_methods :source,
                                  operations: %i[create retrieve update delete list]

    # The API request for deleting a card or bank account and for detaching a
    # source object are the same.
    class << self
      alias detach_source delete_source
    end
  end
end
