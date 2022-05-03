# frozen_string_literal: true

require ::File.expand_path('../../test_helper', __FILE__)

module FedaPay
  class WebhookTest < Minitest::Test
    
    EVENT_PAYLOAD = "{
  \"id\": \"evt_test_webhook\",
  \"object\": \"event\"
}"
    SECRET = "whsec_test_secret";

    def generateHeader(opts = {})
      opts[:timestamp] ||= Time.now
      opts[:payload] ||= EVENT_PAYLOAD
      opts[:secret] ||= SECRET
      opts[:scheme] ||= FedaPay::WebhookSignature.EXPECTED_SCHEME
      opts[:signature] ||= FedaPay::WebhookSignature.computeSignature(
        opts[:timestamp],
        opts[:payload],
        opts[:secret]
      )
      FedaPay::WebhookSignature.generateHeader(
        opts[:timestamp],
        opts[:signature],
        scheme: opts[:scheme]
      )
    end

    describe "compute signature" do
      it "compute a signature which can then be verified" do
        timestamp = Time.now
        signature = FedaPay::WebhookSignature.computeSignature(
          EVENT_PAYLOAD,
          SECRET
        )
        header = generateHeader(timestamp: timestamp, signature: signature)
        assert(FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, SECRET))
      end
    end

    context "generate header" do
      should "generate a header in valid format" do
        timestamp = Time.now
        signature = FedaPay::WebhookSignature.computeSignature(
          EVENT_PAYLOAD,
          SECRET
        )
        scheme = "v1"
        header = FedaPay::WebhookSignature.generateHeader(
          timestamp,
          signature,
          scheme: scheme
        )
        assert_equal("t=#{timestamp.to_i},#{scheme}=#{signature}", header)
      end
    end

    context "construct event" do
      should "return an Event instance from a valid JSON payload and valid signature header" do
        header = generate_header
        event = FedaPay::Webhook.constructEvent(EVENT_PAYLOAD, header, SECRET)
        assert event.is_a?(FedaPay::Event)
      end

      should "raise a JSON::ParserError from an invalid JSON payload" do
        assert_raises JSON::ParserError do
          payload = "this is not valid JSON"
          header = generateHeader(payload: payload)
          FedaPay::Webhook.constructEvent(payload, header, SECRET)
        end
      end

      should "raise a Signature Verification Error from a valid JSON payload and an invalid signature header" do
        header = "bad_header"
        assert_raises FedaPay::SignatureVerificationError do
          FedaPay::Webhook.constructEvent(EVENT_PAYLOAD, header, SECRET)
        end
      end
    end

    context "verify signature header" do
      should "raise a SignatureVerificationError when the header does not have the expected format" do
        header = "i'm not even a real signature header"
        assert_raises(FedaPay::SignatureVerificationError) do
          FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, "secret")
        end
      end

      should "raise a Signature verification error when there are no signatures with the expected scheme" do
        header = generate_header(scheme: "v0")
        assert_raises(FedaPay::SignatureVerificationError) do
          FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, "secret")
        end
      end

      should "raise a Signature verification error when there are no valid signatures for the payload" do
        header = generate_header(signature: "bad_signature")
        assert_raises(FedaPay::SignatureVerificationError) do
          FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, "secret")
        end
      end

      should "raise a Signature verification error when the timestamp is not within the tolerance" do
        header = generate_header(timestamp: Time.now - 15)
        assert_raises(FedaPay::SignatureVerificationError) do
          FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, SECRET, tolerance: 10)
        end
      end

      should "return true when the header contains a valid signature and the timestamp is within the tolerance" do
        header = generate_header
        assert(FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, SECRET, tolerance: 10))
      end

      should "return true when the header contains at least one valid signature" do
        header = generate_header + ",v1=bad_signature"
        assert(FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, SECRET, tolerance: 10))
      end

      should "return true when the header contains a valid signature and the timestamp is off but no tolerance is provided" do
        header = generate_header(timestamp: Time.at(12345))
        assert(FedaPay::WebhookSignature.verifyHeader(EVENT_PAYLOAD, header, SECRET))
      end
    end
  end
end