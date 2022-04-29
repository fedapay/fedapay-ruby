module FedaPay
    class Webhook < APIResource
        OBJECT_NAME = 'webhook'.freeze
        DEFAULT_TOLERANCE = 300

        def self.construct_event(payload, sigHeader, secret, tolerance = DEFAULT_TOLERANCE)
            WebhookSignature::verify_header(payload, sigHeader, secret, tolerance)
            data = JSON.parse(payload, symbolize_names: true)
            Event.construct_from(data)
        end
    end
end