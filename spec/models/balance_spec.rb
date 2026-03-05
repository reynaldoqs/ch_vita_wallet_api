require "rails_helper"

RSpec.describe Balance, type: :model do
  describe "associations" do
    it { should belong_to(:wallet) }
  end

  describe "validations" do
    subject { create(:user).wallet.balances.first }

    it { should validate_presence_of(:currency) }
    it { should validate_inclusion_of(:currency).in_array(Balance::CURRENCIES) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  describe "#fiat? and #crypto?" do
    let(:user) { create(:user) }

    it "identifies fiat currencies" do
      usd = user.wallet.balances.find_by(currency: "USD")
      expect(usd.fiat?).to be true
      expect(usd.crypto?).to be false
    end

    it "identifies crypto currencies" do
      btc = user.wallet.balances.find_by(currency: "BTC")
      expect(btc.fiat?).to be false
      expect(btc.crypto?).to be true
    end
  end
end
