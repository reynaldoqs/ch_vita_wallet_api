FactoryBot.define do
  factory :transaction do
    wallet
    from_currency { "USD" }
    to_currency { "BTC" }
    from_amount { 100.0 }
    to_amount { 0.001 }
    exchange_rate { 100000.0 }
    status { "completed" }
  end
end
