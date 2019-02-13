# frozen_string_literal: true

module FedaPay
  class ApiKey < APIResource
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'api_key'.freeze
  end
end
