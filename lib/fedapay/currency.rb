# frozen_string_literal: true

module FedaPay
  class Currency < APIResource
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'currency'.freeze
  end
end
