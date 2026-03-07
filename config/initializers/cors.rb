cors_origins = ENV.fetch("CORS_ORIGINS", "*").presence || "*"
cors_origins = cors_origins.split(",").map(&:strip) if cors_origins != "*"

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins cors_origins

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization]
  end
end
