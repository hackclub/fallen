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

  # Slack user token (post journals as yourself)
  get "auth/slack/start" => "slack_auth#new", as: :connect_slack
  get "auth/slack/callback" => "slack_auth#create", as: :slack_callback
  delete "auth/slack" => "slack_auth#destroy", as: :disconnect_slack

  resource :pet, only: :update

  resources :projects do
    resources :journals, only: %i[create update destroy], shallow: true
  end

  # Slack app endpoints (signature-verified, no session). See lib/slack_bot and app/bot.
  scope "slack", controller: :slack, as: :slack do
    post "events", action: :events
    post "commands", action: :commands
    post "interactions", action: :interactions
  end

  # Hack Club privacy hub (https://yeet.hackclub.com/docs/deletions). Token verified in the controller, no session.
  scope "api/privacy", controller: "api/privacy", as: :privacy do
    post "delete", action: :delete
    post "export", action: :export
  end

  constraints Constraints::Admin.new do
    namespace :admin do
      root "dashboard#index"
      resources :users, only: %i[index show update] do
        post :impersonate, on: :member
      end
      resources :projects, only: %i[index show]
      mount MissionControl::Jobs::Engine, at: "jobs"
    end
  end

  # Development/test only: sign in without Hack Club Auth (see DevController and db/seeds.rb).
  if Rails.env.local?
    get "dev" => "dev#index", as: :dev
    post "dev/users" => "dev#create", as: :dev_users
    get "dev/sign_in_as/new" => "dev#create", as: :dev_sign_in_as_new
    get "dev/sign_in_as/:id" => "dev#sign_in_as", as: :dev_sign_in_as, constraints: { id: %r{[^/]+} } # ids, public ids or emails
  end
end
