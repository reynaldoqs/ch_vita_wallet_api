require "rails_helper"

RSpec.describe "Api::V1::Prices", type: :request do
  let(:user) { create(:user) }
  let(:mock_prices) do
    {
      "BTC" => { "buy" => "100000", "sell" => "99500" },
      "USDC" => { "buy" => "1.001", "sell" => "0.999" },
      "USDT" => { "buy" => "1.001", "sell" => "0.999" }
    }
  end

  describe "GET /api/v1/prices" do
    context "when API is available" do
      before do
        allow(PriceService).to receive(:fetch_prices).and_return(mock_prices)
      end

      it "returns prices" do
        get "/api/v1/prices", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["prices"]["BTC"]["buy"]).to eq("100000")
      end
    end

    context "when API is unavailable" do
      before do
        allow(PriceService).to receive(:fetch_prices)
          .and_raise(PriceService::ApiError, "Unable to fetch prices")
      end

      it "returns service unavailable" do
        get "/api/v1/prices", headers: auth_headers(user)

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Unable to fetch prices")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/prices"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
