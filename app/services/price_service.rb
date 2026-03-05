class PriceService
  API_URL = "https://api.stage.vitawallet.io/api/prices_quote".freeze
  CACHE_KEY = "crypto_prices".freeze
  CACHE_TTL = 30.seconds

  class ApiError < StandardError; end

  def self.fetch_prices
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      fetch_from_api
    end
  rescue => e
    Rails.logger.error("PriceService error: #{e.message}")
    cached = Rails.cache.read(CACHE_KEY)
    raise ApiError, "Unable to fetch prices" unless cached
    cached
  end

  ASSET_KEYS = %w[btc usdc usdt].freeze

  def self.fetch_from_api
    response = Faraday.get(API_URL) do |req|
      req.headers["Authorization"] = "Bearer #{api_token}" if api_token.present?
      req.options.timeout = 10
      req.options.open_timeout = 5
    end

    raise ApiError, "API returned #{response.status}" unless response.success?

    parse_response(JSON.parse(response.body))
  end

  def self.parse_response(data)
    raw = data["prices"] || data["data"] || data
    raw = raw.slice(*ASSET_KEYS)
    raw.transform_values { |asset| normalize_asset_rates(asset) }
  end

  def self.normalize_asset_rates(asset)
    return asset unless asset.is_a?(Hash)

    result = {}
    asset.each do |k, v|
      next unless k.to_s =~ /\A([a-z]+)_(sell|buy)\z/
      fiat = Regexp.last_match(1).upcase
      side = Regexp.last_match(2)
      result[fiat] ||= {}
      result[fiat][side] = invert_rate(v)
    end
    result
  end

  def self.invert_rate(v)
    n = BigDecimal(v.to_s)
    n.positive? && n < 1 ? (1 / n) : n
  end

  def self.api_token
    Rails.application.credentials.dig(:vitawallet, :api_token) || ENV.fetch("VITAWALLET_API_TOKEN", "")
  end

  private_class_method :fetch_from_api, :parse_response, :normalize_asset_rates, :invert_rate, :api_token
end
