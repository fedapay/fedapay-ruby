# frozen_string_literal: true

module FedaPay
  class ApiKey < APIResource
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::NestedResource

    OBJECT_NAME = 'api_key'.freeze
  end
end
