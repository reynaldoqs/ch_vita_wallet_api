puts "Seeding database..."

user = User.find_or_create_by!(email: "demo@vitawallet.io") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

wallet = user.wallet

{
  "USD" => 1_000,
  "CLP" => 500_000,
  "BTC" => 0.5,
  "USDC" => 100,
  "USDT" => 100
}.each do |currency, amount|
  balance = wallet.balances.find_by(currency: currency)
  balance.update!(amount: amount)
end

puts "Created demo user: demo@vitawallet.io / password123"
puts "Balances: #{wallet.balances.pluck(:currency, :amount).to_h}"
