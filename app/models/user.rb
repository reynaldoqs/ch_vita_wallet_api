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
      w.balances.create!(currency: currency, amount: 0)
    end
  end
end
