Rails.application.routes.draw do
  devise_for :users

  # Root path - customer appointments page
  root "customers/appointments#index"

  # Customer namespace
  namespace :customers do
    resources :appointments, only: %i[index show]
  end

  # Provider namespace
  namespace :providers do
    resource :onboarding, only: :new
    get "dashboard", to: "dashboard#index"
    resources :offices do
      resource :work_schedules, only: %i[new create show edit update], controller: "work_schedules"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
