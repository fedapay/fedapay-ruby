# frozen_string_literal: true

module FedaPay
  class Event < APIResource
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'event'.freeze
  end
end
