module FedaPay
    class Webhook
        DEFAULT_TOLERANCE = 300

        def constructEvent(payload, sigHeader, secret, tolerance = DEFAULT_TOLERANCE)
            WebhookSignature::verifyHeader(payload, sigHeader, secret, tolerance: tolerance)
            data = JSON.parse(payload, symbolize_names: true)
            Event.construct_from(data)
        end
    end
end