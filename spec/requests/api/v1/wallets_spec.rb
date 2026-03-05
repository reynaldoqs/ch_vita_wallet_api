require "rails_helper"

RSpec.describe "Api::V1::Wallets", type: :request do
  describe "GET /api/v1/wallet/balances" do
    let(:user) { create(:user) }

    context "when authenticated" do
      it "returns grouped balances" do
        user.wallet.balances.find_by(currency: "USD").update!(amount: 1000)
        user.wallet.balances.find_by(currency: "BTC").update!(amount: 0.5)

        get "/api/v1/wallet/balances", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["fiat"]).to include("USD" => "1000.0", "CLP" => "0.0")
        expect(json["crypto"]).to include("BTC" => "0.5")
        expect(json["crypto"].keys).to contain_exactly("BTC", "USDC", "USDT")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/wallet/balances"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
