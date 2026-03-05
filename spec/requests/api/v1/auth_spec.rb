require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      { email: "user@example.com", password: "password123", password_confirmation: "password123" }
    end

    context "with valid params" do
      it "creates a user and returns a token" do
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["token"]).to be_present
        expect(json["user"]["email"]).to eq("user@example.com")
      end

      it "creates a wallet with balances" do
        expect { post "/api/v1/auth/register", params: valid_params }
          .to change(User, :count).by(1)
          .and change(Wallet, :count).by(1)
          .and change(Balance, :count).by(5)
      end
    end

    context "with invalid params" do
      it "returns errors for missing email" do
        post "/api/v1/auth/register", params: { password: "password123" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end

      it "returns errors for duplicate email" do
        create(:user, email: "user@example.com")
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns errors for mismatched password confirmation" do
        post "/api/v1/auth/register", params: valid_params.merge(password_confirmation: "wrong")

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "login@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns a token" do
        post "/api/v1/auth/login", params: { email: "login@example.com", password: "password123" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["token"]).to be_present
        expect(json["user"]["email"]).to eq("login@example.com")
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized for wrong password" do
        post "/api/v1/auth/login", params: { email: "login@example.com", password: "wrong" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid email or password")
      end

      it "returns unauthorized for non-existent email" do
        post "/api/v1/auth/login", params: { email: "nobody@example.com", password: "password123" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
