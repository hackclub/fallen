Rails.application.routes.draw do
  # Use one origin in development so the Vite dev server and Rails cookies agree.
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#index"
  get "home" => "home#index", as: :home
  get "sorry" => "bans#show", as: :sorry

  # Hack Club Auth (OAuth)
  get "auth/hca/start" => "auth#new", as: :sign_in
  get "auth/hca/callback" => "auth#create", as: :hca_callback
  delete "auth/sign_out" => "auth#destroy", as: :sign_out
  delete "impersonation" => "impersonations#destroy", as: :impersonation

  # Slack app endpoints (signature-verified, no session). See lib/slack_bot and app/bot.
  scope "slack", controller: :slack, as: :slack do
    post "events", action: :events
    post "commands", action: :commands
    post "interactions", action: :interactions
  end

  constraints Constraints::Admin.new do
    namespace :admin do
      root "dashboard#index"
      resources :users, only: %i[index show update] do
        post :impersonate, on: :member
      end
      mount MissionControl::Jobs::Engine, at: "jobs"
    end
  end

  # Development/test only: sign in without Hack Club Auth (see db/seeds.rb).
  if Rails.env.local?
    get "dev/sign_in_as/:id" => "dev#sign_in_as", as: :dev_sign_in_as, constraints: { id: %r{[^/]+} } # ids, public ids or emails
  end
end
