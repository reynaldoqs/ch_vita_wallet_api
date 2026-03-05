Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"

      get "wallet/balances", to: "wallets#balances"
      get "prices", to: "prices#index"
      post "exchange", to: "exchanges#create"
      get "transactions", to: "transactions#index"
    end
  end
end
