module Api
  module V1
    class PricesController < ApplicationController
      def index
        prices = PriceService.fetch_prices
        render json: prices
      rescue PriceService::ApiError => e
        render json: { message: e.message }, status: :service_unavailable
      end
    end
  end
end
