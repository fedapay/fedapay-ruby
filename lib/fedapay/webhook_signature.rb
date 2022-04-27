module FedaPay
    class WebhookSignature

        EXPECTED_SCHEME = 's';

        def self.verifyHeader(payload, header, secret, tolerance = nil)
            timestamp = getTimestamp(header)
            signatures = getSignatures(header, scheme)
               
            if timestamp == -1
                raise "Unable to extract timestamp and signatures from header"
            end
            
            if signatures.empty?
                raise "No signatures found with expected scheme"
            end

            expectedSignature = compute_signature(payload, secret)
            unless signatures.any? { |s| Util.secure_compare(expectedSignature, s) }
                raise "No signatures found matching the expected signature for payload"
            end

            if tolerance && timestamp < Time.now - tolerance
                raise "Timestamp outside the tolerance zone"
            end 

            true
        end
        
        def self.computeSignature(payload, secret)
            digest = OpenSSL::Digest.new('sha256')
            OpenSSL::HMAC.hexdigest(digest, payload, secret)
        end

        def self.getSignatures(header, scheme)
            items = header.split(',').map { |i| i.split("=", 2) }
            signatures = items.select { |i| i[0] == scheme }.map { |i| i[1] }
        end

        def getTimestamp(header)
            items = header.split(',').map { |i| i.split("=", 2) }
            timestamp = Integer(items.select { |i| i[0] == "t" }[0][1])
            Time.at(timestamp)
        end
    end
end




