require "rails_helper"

RSpec.describe "Api::V1::Exchanges", type: :request do
  let(:user) { create(:user) }
  let(:mock_prices) do
    {
      "BTC" => { "buy" => "100000", "sell" => "99500" },
      "USDC" => { "buy" => "1.001", "sell" => "0.999" },
      "USDT" => { "buy" => "1.001", "sell" => "0.999" }
    }
  end

  before do
    allow(PriceService).to receive(:fetch_prices).and_return(mock_prices)
    user.wallet.balances.find_by(currency: "USD").update!(amount: 10_000)
    user.wallet.balances.find_by(currency: "BTC").update!(amount: 1.0)
  end

  describe "POST /api/v1/exchange" do
    context "fiat to crypto" do
      let(:params) { { from_currency: "USD", to_currency: "BTC", from_amount: 1000 } }

      it "creates a completed transaction" do
        post "/api/v1/exchange", params: params, headers: auth_headers(user)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["transaction"]["status"]).to eq("completed")
        expect(json["transaction"]["from_currency"]).to eq("USD")
        expect(json["transaction"]["to_currency"]).to eq("BTC")
      end

      it "updates balances correctly" do
        post "/api/v1/exchange", params: params, headers: auth_headers(user)

        user.wallet.balances.each(&:reload)
        usd = user.wallet.balances.find_by(currency: "USD")
        btc = user.wallet.balances.find_by(currency: "BTC")

        expect(usd.amount).to eq(9_000)
        expect(btc.amount).to be > 1.0
      end
    end

    context "crypto to fiat" do
      let(:params) { { from_currency: "BTC", to_currency: "USD", from_amount: 0.1 } }

      it "creates a completed transaction" do
        post "/api/v1/exchange", params: params, headers: auth_headers(user)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["transaction"]["status"]).to eq("completed")
      end
    end

    context "with insufficient balance" do
      let(:params) { { from_currency: "USD", to_currency: "BTC", from_amount: 999_999 } }

      it "returns error" do
        post "/api/v1/exchange", params: params, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Insufficient")
      end
    end

    context "with invalid currency pair" do
      let(:params) { { from_currency: "USD", to_currency: "CLP", from_amount: 100 } }

      it "returns error" do
        post "/api/v1/exchange", params: params, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Invalid currency pair")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        post "/api/v1/exchange", params: { from_currency: "USD", to_currency: "BTC", from_amount: 100 }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
