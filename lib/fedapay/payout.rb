# frozen_string_literal: true

module FedaPay
  class Payout < APIResource
    extend FedaPay::APIOperations::List
    extend FedaPay::APIOperations::Create
    include FedaPay::APIOperations::Delete
    include FedaPay::APIOperations::Save
    extend FedaPay::APIOperations::Search

    OBJECT_NAME = 'payout'.freeze

    def send_now(params = {}, opts = {})
      unless (id = self['id'])
        raise InvalidRequestError.new(
          "This action must be performed on a: ]#{self.class} instance", 'id'
        )
      end

      params = { payouts: [{ id: id }] }.merge(params)

      start(params, opts)
    end

    def schedule(scheduled_at, params = {}, opts = {})
      unless (id = self['id'])
        raise InvalidRequestError.new(
          "This action must be performed on a: #{self.class} instance", 'id'
        )
      end

      params = {
        payouts: [{ id: id, scheduled_at: scheduled_at.to_s }]
      }.merge(params)

      start(params, opts)
    end

    def self.schedule_all(payouts = [], params = {}, opts = {})
      items = payouts.map do |payout|
        unless (id = payout['id'])
          raise InvalidRequestError.new(
            'Invalid id argument. You must specify payout id.', 'id'
          )
        end

        item = { id: id}
        item[:scheduled_at] = payout['scheduled_at'] if payout['scheduled_at']
        item
      end

      params = { payouts: items }.merge(params)

      start(params, opts)
    end

    def self.send_all_now(payouts = [], params = {}, opts = {})
      items = payouts.map do |payout|
        unless (id = payout['id'])
          raise InvalidRequestError.new(
            'Invalid id argument. You must specify payout id.', 'id'
          )
        end

        { id: id, send_now: true }
      end

      params = { payouts: items }.merge(params)

      start(params, opts)
    end

    def start(params = {}, opts = {})
      url = "#{self.class.resource_url}/start"

      resp, opts = request(:put, url, params, opts)

      Util.convert_to_fedapay_object(resp.data, opts)
    end
  end
end
