module Api
  module V1
    class WalletsController < ApplicationController
      def balances
        balances = current_user.wallet.balances

        fiat = balances.select(&:fiat?).each_with_object({}) { |b, h| h[b.currency] = b.amount.to_s }
        crypto = balances.select(&:crypto?).each_with_object({}) { |b, h| h[b.currency] = b.amount.to_s }

        render json: { fiat: fiat, crypto: crypto }
      end
    end
  end
end
