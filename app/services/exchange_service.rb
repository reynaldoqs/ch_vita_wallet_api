class ExchangeService
  class ExchangeError < StandardError; end

  VALID_PAIRS = Balance::FIAT_CURRENCIES.product(Balance::CRYPTO_CURRENCIES) +
                Balance::CRYPTO_CURRENCIES.product(Balance::FIAT_CURRENCIES)

  def initialize(wallet:, from_currency:, to_currency:, from_amount:)
    @wallet = wallet
    @from_currency = from_currency.upcase
    @to_currency = to_currency.upcase
    @from_amount = BigDecimal(from_amount.to_s)
  end

  def execute
    validate!
    rate = fetch_rate
    to_amount = calculate_to_amount(rate)

    ActiveRecord::Base.transaction do
      tx = @wallet.transactions.create!(
        from_currency: @from_currency,
        to_currency: @to_currency,
        from_amount: @from_amount,
        to_amount: to_amount,
        exchange_rate: rate,
        status: "pending"
      )

      deduct_balance!
      credit_balance!(to_amount)
      tx.update!(status: "completed")
      tx
    end
  rescue ExchangeError
    raise
  rescue => e
    Rails.logger.error("Exchange failed: #{e.message}")
    raise ExchangeError, "Exchange could not be completed"
  end

  private

  def validate!
    unless VALID_PAIRS.include?([ @from_currency, @to_currency ])
      raise ExchangeError, "Invalid currency pair: #{@from_currency} -> #{@to_currency}"
    end

    raise ExchangeError, "Amount must be greater than 0" if @from_amount <= 0

    source = @wallet.balances.find_by(currency: @from_currency)
    raise ExchangeError, "No #{@from_currency} balance found" unless source
    raise ExchangeError, "Insufficient #{@from_currency} balance" if source.amount < @from_amount
  end

  def fetch_rate
    prices = PriceService.fetch_prices
    lookup_rate(prices)
  rescue PriceService::ApiError => e
    raise ExchangeError, "Could not fetch exchange rate: #{e.message}"
  end

  def lookup_rate(prices)
    crypto = fiat_to_crypto? ? @to_currency : @from_currency
    fiat = fiat_to_crypto? ? @from_currency : @to_currency

    price_data = prices[crypto] || prices[crypto.downcase]
    raise ExchangeError, "Price not available for #{crypto}" unless price_data

    price = if price_data.is_a?(Hash)
      key = fiat_to_crypto? ? "buy" : "sell"
      rate_hash = price_data[fiat] || price_data[fiat.downcase]
      val = rate_hash&.dig(key) || price_data[key] || price_data[fiat] || price_data[fiat.downcase]
      BigDecimal(val&.to_s || "0")
    else
      BigDecimal(price_data.to_s)
    end

    raise ExchangeError, "Invalid price for #{crypto}/#{fiat}" if price.zero?
    price
  end

  def calculate_to_amount(rate)
    if fiat_to_crypto?
      (@from_amount / rate).round(8)
    else
      (@from_amount * rate).round(8)
    end
  end

  def fiat_to_crypto?
    @from_currency.in?(Balance::FIAT_CURRENCIES)
  end

  def deduct_balance!
    source = @wallet.balances.lock.find_by!(currency: @from_currency)
    new_amount = source.amount - @from_amount
    raise ExchangeError, "Insufficient #{@from_currency} balance" if new_amount.negative?
    source.update!(amount: new_amount)
  end

  def credit_balance!(amount)
    dest = @wallet.balances.lock.find_by!(currency: @to_currency)
    dest.update!(amount: dest.amount + amount)
  end
end
