FactoryBot.define do
  factory :balance do
    wallet
    currency { "USD" }
    amount { 0 }
  end
end
