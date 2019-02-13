# frozen_string_literal: true

module FedaPay
  class Log < APIResource
    extend FedaPay::APIOperations::List

    OBJECT_NAME = 'log'.freeze
  end
end
