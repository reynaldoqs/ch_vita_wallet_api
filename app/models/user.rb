class User < ApplicationRecord
  has_secure_password

  has_one :wallet, dependent: :destroy

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }

  after_create :create_wallet_with_balances

  private

  def create_wallet_with_balances
    w = create_wallet!
    Balance::CURRENCIES.each do |currency|
      # Dev/test only: give new users 10_000 USD so they can try exchanges without funding
      amount = currency == "USD" ? 10_000 : 0
      w.balances.create!(currency: currency, amount: amount)
    end
  end
end
