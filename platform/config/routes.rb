Rails.application.routes.draw do
  # Use one origin in development so the Vite dev server and Rails cookies agree.
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # Built assets are served before routing, so this only sees missing ones. Cloudflare caches a 404 on a .js path,
  # and a chunk asked for while a deploy's new pod is starting would otherwise stay broken at the edge after it.
  get "vite/*path", format: false, to: ->(_env) { [ 404, { "cache-control" => "no-store", "content-type" => "text/plain" }, [ "Not found" ] ] }

  # Fallout's email links, /?email=…&code=… (FalloutLinksController)
  get "/" => "fallout_links#show", constraints: ->(req) { req.query_parameters.key?("code") }
  post "welcome" => "fallout_links#create", as: :welcome # The landing page, once a person is on it
  root "landing#index"
  get "home" => "home#index", as: :home
  get "docs(/:page)" => "docs#show", as: :docs, constraints: { page: /[a-z0-9-]+/ }
  get "shop" => "shop#show", as: :shop
  get "transfers" => "transfers#show", as: :transfers
  get "settings" => "settings#show", as: :settings
  get "sorry" => "bans#show", as: :sorry

  # Hack Club Auth (OAuth)
  get "auth/hca/start" => "auth#new", as: :sign_in
  get "auth/hca/callback" => "auth#create", as: :hca_callback
  delete "auth/sign_out" => "auth#destroy", as: :sign_out
  # Starting with just an email, before Hack Club Auth (TrialSessionsController)
  resource :trial_session, only: :create
  delete "impersonation" => "impersonations#destroy", as: :impersonation
  # The landing page's "Get started as", for someone signed in to Hack Club Auth (SlackAvatarsController)
  post "slack_avatar" => "slack_avatars#create", as: :slack_avatar

  # Slack user token (post journals as yourself)
  get "auth/slack/start" => "slack_auth#new", as: :connect_slack
  get "auth/slack/callback" => "slack_auth#create", as: :slack_callback
  post "auth/slack/skip" => "slack_auth#skip", as: :skip_slack
  delete "auth/slack" => "slack_auth#destroy", as: :disconnect_slack

  # Lapse (pick a timelapse for a journal's hours)
  get "auth/lapse/start" => "lapse_auth#new", as: :connect_lapse
  get "auth/lapse/callback" => "lapse_auth#create", as: :lapse_callback
  delete "auth/lapse" => "lapse_auth#destroy", as: :disconnect_lapse
  resource :lapse_sync, only: :create

  resource :pet, only: :update
  resource :hatch, only: :create
  resource :timer, only: %i[show create destroy]
  resource :timer_wrap_up, only: :create
  resources :time_check_ins, only: :update
  resource :huddle_invite, only: :create
  resource :huddle_prompt, only: :create
  resource :huddle_pause, only: %i[create destroy]
  resources :uploads, only: %i[create update]
  # The AI-writing check the journal composer runs before posting (WritingCheck).
  resources :writing_checks, only: %i[create show]

  resources :projects do
    resources :journals, only: %i[create update destroy], shallow: true
    # Teams: invites by name, the link anyone can join with, and leaving or taking someone off.
    resources :invites, controller: :project_invites, only: %i[create show destroy], shallow: true do
      post :accept, on: :member
    end
    resource :join_link, controller: :project_join_links, only: :create
    resources :teammates, controller: :project_teammates, only: :destroy
  end
  get "join/:token" => "project_joins#show", as: :join
  post "join/:token" => "project_joins#create"

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

  # The Slack "join" button's soft signup. Secret checked in the controller, no session.
  post "api/slack/join" => "api/slack_joins#create", as: :slack_join

  # The admin MCP server (McpController, docs/mcp.md). Bearer token checked in the controller, no session.
  post "mcp" => "mcp#handle", as: :mcp, format: false
  match "mcp" => "mcp#not_allowed", via: %i[get put patch delete], format: false

  constraints Constraints::Admin.new do
    namespace :admin do
      root "dashboard#index"
      resources :users, only: %i[index show update] do
        post :impersonate, on: :member
      end
      resources :projects, only: %i[index show update]

      get "stats" => "stats#show", as: :stats
      get "insights(/:kind)" => "insights#show", as: :insights, constraints: { kind: /requests|jobs/ }

      resources :jobs, only: %i[index show destroy] do
        member do
          post :retry
          post :run
        end
        collection do
          post :retry_all
          post :discard_all
        end
      end
      resources :job_queues, only: :update, param: :name, constraints: { name: %r{[^/]+} }
      resources :recurring_tasks, only: [], param: :key do
        post :run, on: :member
      end

      resources :flags, only: %i[index show create update destroy], param: :key, constraints: { key: %r{[^/]+} }

      get "mcp" => "mcp#index", as: :mcp
      resources :mcp_tokens, only: %i[create destroy], controller: :mcp
      resources :sql_changes, only: %i[show update]
    end
  end

  # Development/test only: sign in without Hack Club Auth (see DevController and db/seeds.rb).
  if Rails.env.local?
    get "dev" => "dev#index", as: :dev
    post "dev/users" => "dev#create", as: :dev_users
    get "dev/sign_in_as/new" => "dev#create", as: :dev_sign_in_as_new
    post "dev/skip_slack" => "dev#skip_slack", as: :dev_skip_slack
    get "dev/sign_in_as/:id" => "dev#sign_in_as", as: :dev_sign_in_as, constraints: { id: %r{[^/]+} } # ids, public ids or emails
  end
end
