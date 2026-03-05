require "rails_helper"

RSpec.describe PriceService do
  let(:api_response) do
    {
      "data" => {
        "BTC" => { "buy" => "100000", "sell" => "99500" },
        "USDC" => { "buy" => "1.001", "sell" => "0.999" },
        "USDT" => { "buy" => "1.001", "sell" => "0.999" }
      }
    }.to_json
  end

  before { Rails.cache.clear }

  describe ".fetch_prices" do
    context "when API responds successfully" do
      before do
        stub_request(:get, PriceService::API_URL)
          .to_return(status: 200, body: api_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns parsed prices" do
        prices = described_class.fetch_prices

        expect(prices["BTC"]["buy"]).to eq("100000")
        expect(prices["USDC"]["sell"]).to eq("0.999")
      end

      it "caches the result" do
        described_class.fetch_prices
        described_class.fetch_prices

        expect(WebMock).to have_requested(:get, PriceService::API_URL).once
      end
    end

    context "when API fails" do
      before do
        stub_request(:get, PriceService::API_URL).to_return(status: 500)
      end

      it "raises ApiError when no cache available" do
        expect { described_class.fetch_prices }.to raise_error(PriceService::ApiError)
      end
    end
  end
end
