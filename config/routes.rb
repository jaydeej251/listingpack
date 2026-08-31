Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :brand_kit, only: %i[ edit update ]
  resource :billing, only: %i[ show update ]
  post "billing", to: "billings#update"
  post "paymongo/webhooks", to: "paymongo_webhooks#create", as: :paymongo_webhooks

  get "l/:share_token", to: "public_listings#show", as: :public_listing, constraints: { share_token: /[A-Za-z0-9_-]+/ }

  resources :listings do
    member do
      get :seller_report
    end
    resources :content_packs, only: %i[ create ] do
      collection do
        get :status
        get :posters
        post :retry
      end
      resources :captions, only: :update
      resources :generated_assets, only: [] do
        member do
          post :regenerate
        end
      end
    end
  end

  resources :weekly_calendars, only: %i[ index show create ] do
    member do
      post :retry
    end
  end

  namespace :admin do
    resources :failures, only: :index
  end

  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "guide", to: "pages#guide"
  get "publishing", to: "pages#publishing"

  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
end
