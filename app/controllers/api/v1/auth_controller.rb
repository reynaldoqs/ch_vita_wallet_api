module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_request, only: %i[register login]

      def register
        user = User.new(auth_params)

        if user.save
          token = JwtService.encode(user_id: user.id)
          render json: { token: token, user: user_json(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email])

        if user&.authenticate(params[:password])
          token = JwtService.encode(user_id: user.id)
          render json: { token: token, user: user_json(user) }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      private

      def auth_params
        params.permit(:email, :password, :password_confirmation)
      end

      def user_json(user)
        { id: user.id, email: user.email }
      end
    end
  end
end
