require "rails_helper"

RSpec.describe ExchangeService do
  let(:user) { create(:user) }
  let(:wallet) { user.wallet }
  let(:mock_prices) do
    {
      "BTC" => { "buy" => "100000", "sell" => "99500" },
      "USDC" => { "buy" => "1.001", "sell" => "0.999" },
      "USDT" => { "buy" => "1.001", "sell" => "0.999" }
    }
  end

  before do
    allow(PriceService).to receive(:fetch_prices).and_return(mock_prices)
    wallet.balances.find_by(currency: "USD").update!(amount: 10_000)
    wallet.balances.find_by(currency: "BTC").update!(amount: 1.0)
  end

  describe "#execute" do
    context "fiat to crypto (USD -> BTC)" do
      subject do
        described_class.new(
          wallet: wallet, from_currency: "USD", to_currency: "BTC", from_amount: 1000
        )
      end

      it "creates a completed transaction" do
        tx = subject.execute

        expect(tx.status).to eq("completed")
        expect(tx.from_currency).to eq("USD")
        expect(tx.to_currency).to eq("BTC")
        expect(tx.from_amount).to eq(1000)
        expect(tx.to_amount).to eq(BigDecimal("1000") / BigDecimal("100000"))
      end

      it "deducts from source and credits destination" do
        subject.execute
        wallet.balances.each(&:reload)

        expect(wallet.balances.find_by(currency: "USD").amount).to eq(9_000)
        expect(wallet.balances.find_by(currency: "BTC").amount).to eq(BigDecimal("1.01"))
      end
    end

    context "crypto to fiat (BTC -> USD)" do
      subject do
        described_class.new(
          wallet: wallet, from_currency: "BTC", to_currency: "USD", from_amount: 0.1
        )
      end

      it "creates a completed transaction" do
        tx = subject.execute

        expect(tx.status).to eq("completed")
        expect(tx.from_amount).to eq(BigDecimal("0.1"))
        expect(tx.to_amount).to eq(BigDecimal("0.1") * BigDecimal("99500"))
      end
    end

    context "with insufficient balance" do
      subject do
        described_class.new(
          wallet: wallet, from_currency: "USD", to_currency: "BTC", from_amount: 999_999
        )
      end

      it "raises an error" do
        expect { subject.execute }.to raise_error(ExchangeService::ExchangeError, /Insufficient/)
      end

      it "does not create a transaction" do
        expect { subject.execute rescue nil }.not_to change(Transaction, :count)
      end
    end

    context "with invalid currency pair (fiat to fiat)" do
      subject do
        described_class.new(
          wallet: wallet, from_currency: "USD", to_currency: "CLP", from_amount: 100
        )
      end

      it "raises an error" do
        expect { subject.execute }.to raise_error(ExchangeService::ExchangeError, /Invalid currency pair/)
      end
    end

    context "with zero amount" do
      subject do
        described_class.new(
          wallet: wallet, from_currency: "USD", to_currency: "BTC", from_amount: 0
        )
      end

      it "raises an error" do
        expect { subject.execute }.to raise_error(ExchangeService::ExchangeError, /greater than 0/)
      end
    end
  end
end
