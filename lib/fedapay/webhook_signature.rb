module FedaPay
    class WebhookSignature

        EXPECTED_SCHEME = 's';

        def self.verify_header(payload, header, secret, tolerance = nil)
            timestamp = get_timestamp(header)
            signatures = get_signatures(header, EXPECTED_SCHEME)
               
            if timestamp == -1
                raise "Unable to extract timestamp and signatures from header"
            end
            
            if signatures.empty?
                raise SignatureVerificationError.new(
                    "No signatures found with expected scheme #{EXPECTED_SCHEME}",
                    header, http_body: payload
                )
            end

            signed_payload = "#{timestamp.to_i}.#{payload}"
            expected_signature = compute_signature(signed_payload, secret)
            unless signatures.any? { |s| Util.secure_compare(expected_signature, s) }
                raise SignatureVerificationError.new(
                    "No signatures found matching the expected signature for payload",
                    header, http_body: payload
                )
            end

            if tolerance && timestamp < Time.now - tolerance
                raise SignatureVerificationError.new(
                    "Timestamp outside the tolerance zone (#{Time.at(timestamp)})",
                    header, http_body: payload
                )
            end 

            true
        end

        def self.generate_header(timestamp, signature, scheme: EXPECTED_SCHEME)
            unless timestamp.is_a?(Time) 
                raise "timestamp should be an instance of Time"
            end
            unless signature.is_a?(String) 
                raise "signature should be a string"
            end
            unless scheme.is_a?(String) 
                raise "scheme should be a string"
            end

            "t=#{timestamp.to_i},#{scheme}=#{signature}"
        end
        
        def self.compute_signature(payload, secret)
            digest = OpenSSL::Digest.new('sha256')
            OpenSSL::HMAC.hexdigest(digest, secret, payload)
        end

        def self.get_signatures(header, scheme)
            items = header.split(',').map { |i| i.split("=", 2) }
            signatures = items.select { |i| i[0] == scheme }.map { |i| i[1] }
        end

        def self.get_timestamp(header)
            items = header.split(',').map { |i| i.split("=", 2) }
            timestamp = Integer(items.select { |i| i[0] == "t" }[0][1])
            Time.at(timestamp)
        end
    end
end




