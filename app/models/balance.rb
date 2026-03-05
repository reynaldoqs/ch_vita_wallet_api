class Balance < ApplicationRecord
  FIAT_CURRENCIES = %w[USD CLP].freeze
  CRYPTO_CURRENCIES = %w[BTC USDC USDT].freeze
  CURRENCIES = (FIAT_CURRENCIES + CRYPTO_CURRENCIES).freeze

  belongs_to :wallet

  validates :currency, presence: true, inclusion: { in: CURRENCIES }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, uniqueness: { scope: :wallet_id }

  def fiat?
    currency.in?(FIAT_CURRENCIES)
  end

  def crypto?
    currency.in?(CRYPTO_CURRENCIES)
  end
end
