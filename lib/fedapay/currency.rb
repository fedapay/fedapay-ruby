# frozen_string_literal: true

module FedaPay
  class Currency < APIResource
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = 'currency'.freeze
  end
end
