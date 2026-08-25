Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :brand_kit, only: %i[ edit update ]
  resource :billing, only: %i[ show update ]

  resources :listings do
    member do
      patch :confirm_price
      get :seller_report
    end
    resources :content_packs, only: %i[ create ] do
      collection do
        get :status
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

  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
end
