# frozen_string_literal: true

module FedaPay
  class Payout < APIResource
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::Create
    extend FedaPay::APIOperations::Delete
    extend FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = 'payout'.freeze
  end
end
