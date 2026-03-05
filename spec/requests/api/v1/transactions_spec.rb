require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user) { create(:user) }
  let(:wallet) { user.wallet }

  before do
    create_list(:transaction, 3, wallet: wallet, status: "completed")
    create_list(:transaction, 2, wallet: wallet, status: "pending")
    create(:transaction, wallet: wallet, status: "rejected")
  end

  describe "GET /api/v1/transactions" do
    context "when authenticated" do
      it "returns paginated transactions" do
        get "/api/v1/transactions", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(6)
        expect(json["meta"]["total_count"]).to eq(6)
      end

      it "filters by status" do
        get "/api/v1/transactions", params: { status: "completed" }, headers: auth_headers(user)

        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(3)
        expect(json["transactions"].map { |t| t["status"] }.uniq).to eq([ "completed" ])
      end

      it "paginates results" do
        get "/api/v1/transactions", params: { page: 1, per_page: 2 }, headers: auth_headers(user)

        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(2)
        expect(json["meta"]["total_pages"]).to eq(3)
        expect(json["meta"]["current_page"]).to eq(1)
      end

      it "returns transactions in reverse chronological order" do
        get "/api/v1/transactions", headers: auth_headers(user)

        json = JSON.parse(response.body)
        dates = json["transactions"].map { |t| t["created_at"] }
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/transactions"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
