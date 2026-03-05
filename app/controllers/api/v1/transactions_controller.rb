module Api
  module V1
    class TransactionsController < ApplicationController
      def index
        transactions = current_user.wallet.transactions
          .by_status(params[:status])
          .order(created_at: :desc)
          .page(params[:page])
          .per(params[:per_page] || 10)

        render json: {
          transactions: transactions.map { |tx| transaction_json(tx) },
          meta: {
            current_page: transactions.current_page,
            total_pages: transactions.total_pages,
            total_count: transactions.total_count
          }
        }
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
