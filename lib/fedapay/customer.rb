# frozen_string_literal: true

module FedaPay
  class Customer < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'customer'.freeze

    save_nested_resource :transaction
    nested_resource_class_methods :transaction,
                                  operations: %i[create retrieve update delete list]

    # The API request for deleting a card or bank account and for detaching a
    # source object are the same.
    class << self
      alias detach_transaction delete_transaction
    end
  end
end
