# frozen_string_literal: true

module FedaPay
  class Transaction < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = 'transaction'.freeze
  end
end
