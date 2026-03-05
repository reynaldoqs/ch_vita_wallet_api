require "rails_helper"

RSpec.describe JwtService do
  let(:payload) { { user_id: 1 } }

  describe ".encode" do
    it "returns a JWT token string" do
      token = described_class.encode(payload)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end
  end

  describe ".decode" do
    it "decodes a valid token" do
      token = described_class.encode(payload)
      decoded = described_class.decode(token)

      expect(decoded[:user_id]).to eq(1)
    end

    it "returns nil for invalid token" do
      expect(described_class.decode("invalid.token.here")).to be_nil
    end

    it "returns nil for expired token" do
      expired_payload = { user_id: 1, exp: 1.hour.ago.to_i }
      token = JWT.encode(expired_payload, JwtService::SECRET, JwtService::ALGORITHM)

      expect(described_class.decode(token)).to be_nil
    end
  end
end
