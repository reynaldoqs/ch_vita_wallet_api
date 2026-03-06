require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_one(:wallet).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should have_secure_password }
  end

  describe "callbacks" do
    it "creates a wallet with all currency balances after creation" do
      user = create(:user)

      expect(user.wallet).to be_present
      expect(user.wallet.balances.count).to eq(5)
      expect(user.wallet.balances.pluck(:currency).sort).to eq(Balance::CURRENCIES.sort)
      expect(user.wallet.balances.find_by(currency: "USD").amount).to eq(10_000)
      expect(user.wallet.balances.where.not(currency: "USD").pluck(:amount).uniq).to eq([ 0 ])
    end
  end

  describe "email validation" do
    it "rejects invalid emails" do
      user = build(:user, email: "invalid")
      expect(user).not_to be_valid
    end

    it "accepts valid emails" do
      user = build(:user, email: "test@example.com")
      expect(user).to be_valid
    end
  end
end
