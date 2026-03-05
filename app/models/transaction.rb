class Transaction < ApplicationRecord
  STATUSES = %w[pending completed rejected].freeze

  belongs_to :wallet

  validates :from_currency, presence: true, inclusion: { in: Balance::CURRENCIES }
  validates :to_currency, presence: true, inclusion: { in: Balance::CURRENCIES }
  validates :from_amount, presence: true, numericality: { greater_than: 0 }
  validates :to_amount, presence: true, numericality: { greater_than: 0 }
  validates :exchange_rate, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :by_status, ->(status) { where(status: status) if status.present? }
end
