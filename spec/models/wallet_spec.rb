require "rails_helper"

RSpec.describe Wallet, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:balances).dependent(:destroy) }
    it { should have_many(:transactions).dependent(:destroy) }
  end
end
