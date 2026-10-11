# platform

Rails 8.1, Inertia, Svelte 5, Tailwind 4, PostgreSQL. Run everything in this folder.

## Setup

```sh
docker compose up -d db          # or set DATABASE_URL to your own Postgres
bin/setup                        # bundle + npm install, copies .env.development, prepares the DB, starts bin/dev
```

`bin/dev` starts Rails on 3000, Vite on 3036, the Solid Queue worker, and the Slack Socket Mode bridge (idle until
Slack tokens are set).

To sign in without Hack Club Auth:

```sh
bin/rails db:seed
open http://localhost:3000/dev/sign_in_as/admin@example.com
```

### Hack Club Auth

Create an app at [auth.hackclub.com](https://auth.hackclub.com) with callback `http://localhost:3000/auth/hca/callback`
and set `HCA_CLIENT_ID` and `HCA_CLIENT_SECRET` in `.env.development`. Development uses the staging instance
(`hca.dinosaurbbq.org`), production uses `auth.hackclub.com`. Override with `HCA_HOST`.

## Slack bot

`SlackController` handles `/slack/events`, `/slack/commands` and `/slack/interactions` (signature verified). Payloads
are routed by name to classes in `app/bot`:

| Slack | Class |
| --- | --- |
| `/ping` | `PingCommand < SlackBot::Command` |
| `app_mention` event | `AppMentionEvent < SlackBot::Event` |
| button `action_id: "say_hello"` (or `"say_hello:42"`) | `SayHelloAction < SlackBot::Action` |
| modal `callback_id: "feedback"` | `FeedbackView < SlackBot::View` |
| shortcut `callback_id: "report"` | `ReportShortcut < SlackBot::Shortcut` |

A handler implements `call`. Available inside: `payload` (dot access, missing keys are `nil`), `client`, `user` (the
`User` whose `slack_id` matches), `say`, `reply`, `respond`, `ephemeral`, `open_modal`, `update_message`, and the
Block Kit helpers from `SlackBot::Blocks`.

```ruby
# app/bot/standup_command.rb  ->  /standup
class StandupCommand < SlackBot::Command
  description "Post today's standup"

  def call
    return respond("Sign in first: #{ENV['APP_URL']}") unless user

    say blocks: [ header("Standup from #{user.display_name}"), section(text) ], in_channel: true
    respond "Posted!"
  end
end
```

Events run in `SlackEventJob`. Commands and interactions run inline; the first `respond` in a command is the ack,
later ones go to `response_url`. Views return `errors(field: "message")`, `update_view`, `push_view` or `close`.

Local dev, no tunnel:

1. `bin/slack-manifest --socket-mode` prints a manifest. Create the app from it at
   [api.slack.com/apps](https://api.slack.com/apps) and install it.
2. Set `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET` and `SLACK_APP_TOKEN` (`connections:write`) in `.env.development`.
3. Restart `bin/dev`. `script/slack_socket_mode.mjs` forwards Socket Mode payloads to the local app as signed HTTP
   requests.

For production, `bin/slack-manifest https://your.app` and disable Socket Mode.

## Privacy requests

The Hack Club privacy hub calls `POST /api/privacy/delete` and `/api/privacy/export` to delete a person's data. What
gets deleted and kept is in [docs/privacy.md](docs/privacy.md). Update it when you add a table that holds user data.

## Layout

```
app/
  bot/            Slack handlers
  controllers/    admin/ is admin-only
  frontend/       entrypoints/, layouts/, components/, pages/<Controller>/<Action>.svelte, lib/, types/, routes/
  jobs/           Solid Queue jobs
  models/         User, concerns (PublicIdentifiable, Discardable)
  policies/       Pundit
  serializers/    Alba serializers; typelizer generates app/frontend/types and app/frontend/routes from these + routes.rb
  services/       HCA client, privacy hub token and deletion
docs/             privacy.md
lib/
  slack_bot/      Router, Handler, Command/Event/Action/View/Shortcut, Blocks, Manifest, Payload
  constraints/    Constraints::Admin, Constraints::Staff
```

Props go through serializers; the frontend imports their types from `@/types` and URLs from `@/routes`
(`adminUser(user.id)`). Regenerate by hand with `bin/rails typelizer:generate`; CI fails if the committed output is
stale.

Records use public ids (`usr_Ab12Cd`). Pundit fails closed: every action must `authorize`, every index must
`policy_scope`. Admins can impersonate users; PaperTrail records the admin.

## Checks

```sh
bin/rubocop && bin/brakeman --no-pager && bin/rails test
npm run check && npm run format:check
```

## Deploy

Two Coolify services from this folder (set it as the base directory), Dockerfile build pack, same env vars
(`.env.production.example`):

1. web: `Dockerfile`, port 80, health check `GET /up`.
2. worker: `Dockerfile.worker`, no port, no health check. Runs `bin/jobs`.

Secrets are ENV only. `bin/rails secret` for `SECRET_KEY_BASE`, `bin/rails db:encryption:init` for the
`ACTIVE_RECORD_ENCRYPTION_*` keys. Set `HASHID_SALT` once and never change it. Deploy web first (it runs
`db:prepare`), then the worker. `SOLID_QUEUE_IN_PUMA=1` runs jobs inside the web container if you want one service.

Uploads go to Cloudflare R2 when `R2_BUCKET` is set. Mail goes through Loops when `LOOPS_API_KEY` is set.
