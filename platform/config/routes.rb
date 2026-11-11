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
  get "stats" => "stats#show", as: :stats
  get "transfers" => "transfers#show", as: :transfers
  get "settings" => "settings#show", as: :settings
  get "sorry" => "bans#show", as: :sorry
  # The workshop sign-up (WorkshopRsvp), linked only from the invite email.
  get "workshops/rsvp" => "workshop_rsvps#new", as: :workshop_rsvp
  post "workshops/rsvp" => "workshop_rsvps#create"
  get "rsvp", as: nil, to: redirect { |_params, req| "/workshops/rsvp#{"?#{req.query_string}" if req.query_string.present?}" }

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
  # The welcome back's answers, and the dashboard's Slack ping box (DayEndReminder).
  resource :welcome_back, only: :create
  resource :pronouns, only: :update # Settings > Profile
  resource :day_end_reminder, only: %i[create destroy]
  # Their own daily goal in place of the suggested one (DailyGoal), and back.
  resource :daily_goal, only: %i[update destroy]
  resource :timer, only: %i[show create destroy]
  resource :timer_wrap_up, only: :create
  resources :time_check_ins, only: :update
  resource :huddle_invite, only: :create
  resource :huddle_prompt, only: :create
  resource :huddle_pause, only: %i[create destroy]
  resources :uploads, only: %i[create update]
  # Which photos in a journal draft are already on another journal (PhotoChecksController).
  resources :photo_checks, only: :create
  # The AI-writing check the journal composer runs before posting (WritingCheck).
  resources :writing_checks, only: %i[create show]
  # Turns a bom.csv into rows for the submit popup (BomImport).
  resources :bom_imports, only: :create

  resources :projects do
    resources :journals, only: %i[create update destroy], shallow: true do
      patch :move, on: :member
    end
    # Teams: invites by name, the link anyone can join with, and leaving or taking someone off.
    resources :invites, controller: :project_invites, only: %i[create show destroy], shallow: true do
      post :accept, on: :member
    end
    resource :join_link, controller: :project_join_links, only: :create
    # Design submission: the submit popup's steps (repo check, checks) and sending it.
    resources :submissions, only: %i[create destroy], shallow: true
    resources :repo_snapshots, only: %i[create show], shallow: true
    resource :submission_check, only: :create
    # Journal review from the team's side: asking for one.
    resource :review_request, only: :create
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

  # The design review queue (SubmissionReview), part of the admin panel but open to design reviewers too, so it's
  # routed before the admins-only constraint below.
  constraints Constraints::DesignReviewer.new do
    namespace :review, path: "admin/reviews" do
      root "submissions#index"
      get "next" => "submissions#next", as: :next
      resources :submissions, only: %i[index show update] do
        member do
          post :heartbeat
          patch :draft
          post :release
          post :take_over
          post :flag
          post :unflag
        end
        resources :notes, only: :create
        resources :repo_files, only: :create
      end
    end
  end

  # Journal review (ProgressReview), open to reviewers and admins, the same way.
  constraints Constraints::JournalReviewer.new do
    scope "admin/journal-reviews", module: :review, as: :journal_review do
      root "progress#index"
      get "next" => "progress#next", as: :next
      # Admins put a project in the queue by its link.
      post "add" => "progress#add", as: :add
      resources :projects, controller: :progress, only: %i[index show update] do
        member do
          post :heartbeat
          post :release
          post :take_over
          post :flag
          post :unflag
          post :star
          post :unstar
        end
      end
      # Editing the feedback on a review that's already gone out.
      resources :reviews, controller: :progress_reviews, only: :update
    end
    # Projects reviewers starred as standouts, and ones flagged as written by AI (ProgressStatus), each on its own page.
    scope "admin", module: :review do
      get "starred" => "marked_projects#index", defaults: { kind: "starred" }, as: :starred_projects
      get "ai-flags" => "marked_projects#index", defaults: { kind: "flagged" }, as: :ai_flagged_projects
    end
  end

  # Project transfers, open to reviewers and admins. Pulling the form from Airtable stays admins-only (the policy).
  constraints Constraints::TransferReviewer.new do
    namespace :admin do
      resources :transfers, only: %i[index show] do
        member do
          post :approve
          post :reject
          patch :draft
          post :reach_out
          delete :reach_out, action: :undo_reach_out
          post :refetch
        end
        resource :lapse, only: %i[show update], controller: "transfer_lapses" do
          patch :annotations
        end
        post :sync, on: :collection
      end
    end
  end

  constraints Constraints::Admin.new do
    namespace :admin do
      root "dashboard#index"
      resources :users, only: %i[index show update] do
        post :impersonate, on: :member
      end
      resources :projects, only: %i[index show update]
      resources :streaks, only: :index
      resources :workshop_rsvps, only: :index, path: "workshop-rsvps" do
        get :export, on: :collection # A CSV of the emails, for sending the link on the day
      end
      # Design funding sent through HCB (GrantPayout), and connecting HCB.
      resources :grants, only: :index do
        member do
          post :send_now
          post :retry
          post :mark_sent
        end
        collection do
          get :connect, as: :hcb_connect
          get :callback, as: :hcb_callback
        end
      end
      resources :streak_adjustments, only: %i[create destroy]

      get "stats" => "stats#show", as: :stats
      get "teams" => "teams#show", as: :teams
      get "qualifying" => "qualifying#show", as: :qualifying
      post "teams/pay" => "teams#pay", as: :pay_teams
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
