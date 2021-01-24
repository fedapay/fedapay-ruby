# frozen_string_literal: true

module FedaPay
  class Account < APIResource
    extend Gem::Deprecate
    extend FedaPay::APIOperations::Create
    extend FedaPay::APIOperations::List
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save

    OBJECT_NAME = 'account'.freeze

    def resource_url
      if self['id']
        super
      else
        '/accounts'
      end
    end
  end
end
