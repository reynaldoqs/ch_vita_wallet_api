module Api
  module V1
    class ExchangesController < ApplicationController
      def create
        service = ExchangeService.new(
          wallet: current_user.wallet,
          from_currency: params[:from_currency],
          to_currency: params[:to_currency],
          from_amount: params[:from_amount]
        )

        transaction = service.execute

        render json: {
          transaction: transaction_json(transaction)
        }, status: :created
      rescue ExchangeService::ExchangeError => e
        render json: { message: e.message }, status: :unprocessable_entity
      end

      private

      def transaction_json(tx)
        {
          id: tx.id,
          from_currency: tx.from_currency,
          to_currency: tx.to_currency,
          from_amount: tx.from_amount.to_s,
          to_amount: tx.to_amount.to_s,
          exchange_rate: tx.exchange_rate.to_s,
          status: tx.status,
          created_at: tx.created_at
        }
      end
    end
  end
end
