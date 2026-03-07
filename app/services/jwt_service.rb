class JwtService
  SECRET = Rails.application.credentials.secret_key_base || ENV.fetch("SECRET_KEY_BASE")
  ALGORITHM = "HS256"
  EXPIRATION = (ENV.fetch("JWT_EXPIRATION_HOURS", "24").to_i).hours

  def self.encode(payload)
    payload[:exp] = EXPIRATION.from_now.to_i
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::DecodeError
    nil
  end
end
