# frozen_string_literal: true

module FedaPay
  class Customer < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'customer'.freeze
  end
end
