require "rails_helper"

RSpec.describe Transaction, type: :model do
  describe "associations" do
    it { should belong_to(:wallet) }
  end

  describe "validations" do
    it { should validate_presence_of(:from_currency) }
    it { should validate_presence_of(:to_currency) }
    it { should validate_presence_of(:from_amount) }
    it { should validate_presence_of(:to_amount) }
    it { should validate_presence_of(:exchange_rate) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:from_currency).in_array(Balance::CURRENCIES) }
    it { should validate_inclusion_of(:to_currency).in_array(Balance::CURRENCIES) }
    it { should validate_inclusion_of(:status).in_array(Transaction::STATUSES) }
    it { should validate_numericality_of(:from_amount).is_greater_than(0) }
    it { should validate_numericality_of(:to_amount).is_greater_than(0) }
    it { should validate_numericality_of(:exchange_rate).is_greater_than(0) }
  end

  describe ".by_status" do
    let(:user) { create(:user) }
    let(:wallet) { user.wallet }

    before do
      create(:transaction, wallet: wallet, status: "completed")
      create(:transaction, wallet: wallet, status: "pending")
      create(:transaction, wallet: wallet, status: "rejected")
    end

    it "filters by status" do
      expect(Transaction.by_status("completed").count).to eq(1)
      expect(Transaction.by_status("pending").count).to eq(1)
    end

    it "returns all when status is nil" do
      expect(Transaction.by_status(nil).count).to eq(3)
    end
  end
end
