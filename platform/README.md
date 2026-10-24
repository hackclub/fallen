# platform

Rails 8.1, Inertia, Svelte 5, Tailwind 4, PostgreSQL. Run everything in this folder.

## Setup

```sh
docker compose up -d db          # or set DATABASE_URL to your own Postgres
bin/setup                        # bundle + npm install, copies .env.development, prepares the DB, starts bin/dev
```

`bin/dev` starts Rails on 3000, Vite on 3036, the Solid Queue worker, and the Slack Socket Mode bridge (idle until
Slack tokens are set).

To sign in without Hack Club Auth, open http://localhost:3000/dev (Get started goes there when HCA isn't
configured). It lists accounts to sign in as and makes new ones with whatever roles, pet and flags you need.
From a script or bookmark:

```sh
open http://localhost:3000/dev/sign_in_as/admin@example.com     # an existing account (email, usr_ id or id)
open "http://localhost:3000/dev/sign_in_as/new?roles[]=admin"   # a brand new one
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

## Projects and journals

A project is one Slack thread in the journals channel (`SLACK_JOURNALS_CHANNEL_ID`, invite the bot). Its top-level
message is the project; each reply by the owner is a journal. Both sides stay in sync:

- Slack -> web: the owner's replies in their thread are collected into a `JournalDraft` (`MessageEvent`), since they
  may just be chatting. Replies by anyone else are ignored. Once the owner stops posting for a moment,
  `JournalPromptJob` asks them privately: a time box under their text with "Save journal" (`JournalDraftAction`), "Add more" (later
  replies join the same journal) or "Not a journal". Photos posted on their own get "Add to last journal" or "Save
  for my next one". `CollectSlackJournalJob` copies the photos onto the journal (bot scope `files:read`) and reacts to
  each reply. Edits and deletions of any reply in Slack update the draft or journal.
- Projects are only started on the web; `/project` links there. Any other top-level post in the journals channel is
  deleted through [Prometheus](https://github.com/hackclub/prometheus) (`RemoveStrayPostJob`,
  `PROMETHEUS_API_KEY`, a key a channel manager makes for the journals channel), and the author gets their text back.
- Before that happens: `bin/slack-typing` watches who starts typing a top-level post and `TypingHintJob` sends them
  a hidden hint, with a "Start a project" button or links to the threads of projects they already have. Slack only
  reports typing to its own clients, so it signs in as an account in the channel (`SLACK_BROWSER_TOKEN`, an `xoxc-`
  token, and `SLACK_BROWSER_COOKIE`, its `d` cookie; `SlackBot::BrowserSocket`). In production it runs next to
  Solid Queue in the worker container (`bin/worker`).
- The same account sits in a huddle in `SLACK_HUDDLE_CHANNEL_ID` around the clock (`script/slack_huddle.mjs`,
  started by `bin/worker` and `bin/dev`). Huddles have no public API, so it joins the way the desktop client does
  (`rooms.join`, as [huddlefm](https://github.com/ingoau/huddlefm) does) and then connects to the Amazon Chime
  meeting behind the huddle over WebRTC, since Slack only lists a participant whose audio is connected. It sends no
  sound. Slack stops every huddle after 24 hours; when that or anything else ends the connection, it joins again.
- `bin/slack-typing` also hears people join and leave that huddle and runs `HuddleSyncJob` (and every minute in case it
  missed one), which keeps `Huddle` and `HuddleSession` rows: who was in it and when, plus what they said they were
  working on. Everyone joining gets a hidden "what are you working on today?" in the huddle's thread, from their pet
  ("are you still working on ...?" when they had a goal), and again every 10 thread messages until they answer
  (`HuddlePromptJob`, `HuddleGoalAction`); committing posts their goal in the thread (`HuddleCommitJob`). Dropping out
  for under 30 seconds keeps an answer. People without a Fallen account, or a project, get a button to start one;
  their visits join their account once they link Slack. When Slack ends a huddle, the people still in it are mentioned in the
  new huddle's thread and rung into it (`HuddleHandoffJob`, `rooms.notifyMember`), and keep their answer if they join
  within 15 minutes. A huddle that has run 12 hours with only the bot in it is restarted. The bot needs to be in the
  huddle channel.
- Web -> Slack: `PostProjectToSlackJob` posts the thread anchor, `SyncJournalToSlackJob` posts, edits and deletes
  journal replies. Messages go out as the person when they have connected Slack (`SlackAuthController`, user scope
  `chat:write`, needs `SLACK_CLIENT_ID` / `SLACK_CLIENT_SECRET` and the redirect URL from the manifest). Someone who
  skips that has the bot post under their name and avatar (`chat:write.customize`); each message records which one
  posted it (`slack_posted_by_bot`), since only the poster can edit or delete it.
- Slack "join" button: point its webhook at `POST /api/slack/join` with `Authorization: Bearer <SLACK_JOIN_SECRET>`
  (or `?secret=`) and the Slack ID as `slack_id`, in a JSON or form body or the query string. UTM tags and `ref` sent
  alongside are kept as the account's signup source, like a tagged link's (`ref` is `slack-join` when none is sent).
  `SlackJoinJob` makes a trial account from their Slack profile (email through `SLACK_LOOKUP_TOKEN`), so they are in
  Airtable right away. Signing in with Hack Club Auth later claims it by Slack ID.
- Fallout email links: `/?email=…&code=…` with the `verifyCode` Fallout's Airtable has for that email is a soft signup
  like the Slack join button: it makes a trial account for the email and signs nobody in (`FalloutLinksController`,
  `User.join_from_fallout!`). Signing in with Hack Club Auth later claims it by email. Mail scanners open links, so
  following one only keeps the checked email in the session and redirects to a clean URL; the landing page posts it
  back once a person moves the mouse, touches or types. Someone already signed in to Hack Club Auth goes straight on to
  sign in instead. `SyncFalloutInvitesJob` copies HMACs of every email and code pair when run by hand (it is not scheduled) with
  `AIRTABLE_API_KEY`, which needs `data.records:read` on Fallout's base too, so a link never waits on Airtable. Every
  link lands on the page the same way, and Rack::Attack limits tries per IP and per email. Soft-signup accounts are
  marked (`users.soft_signup`) because only those are claimed at sign-in: a trial from the email form could be anyone's.

Every journal has a time. It is typed, never picked from presets ("1.5", "1h 30m", `Duration.parse`), and stored as minutes.
It also needs a photo for every two hours of it (`Journal::MINUTES_PER_IMAGE`).

## XP, teams and pets

Every journal with hours earns XP (`XpEntry::PER_HOUR`) into a ledger, `xp_entries`; `users.xp` is its sum. The pet
picked in onboarding is also the team (`Team::Lulu`, `Team::Sami`), and `CloseWeekJob` settles each week on the
Monday after it: the team that earned the most XP pays its contributors, Lulu pays for enough journal days, Sami
raises or resets the multiplier that applies to new journals. The pet's form follows XP (`Evolution`); the final
form also needs a project approved on its admin page. Run a week again with `CloseWeekJob.perform_now(date)`.

## Privacy requests

The Hack Club privacy hub calls `POST /api/privacy/delete` and `/api/privacy/export` to delete a person's data. What
gets deleted and kept is in [docs/privacy.md](docs/privacy.md). Update it when you add a table that holds user data.

## Admin MCP

Admins can let an MCP client (Claude Code, Cursor, VS Code, Codex) use the admin panel through `POST /mcp`. Make a
token at `/admin/mcp` and add it with the config it shows. How it works and what it can't do is in [docs/mcp.md](docs/mcp.md).

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
docs/             privacy.md, performance.md, mcp.md
lib/
  slack_bot/      Router, Handler, Command/Event/Action/View/Shortcut, Blocks, Manifest, Payload, BrowserSocket
  constraints/    Constraints::Admin, Constraints::Staff
```

Props go through serializers; the frontend imports their types from `@/types` and URLs from `@/routes`
(`adminUser(user.id)`). Regenerate by hand with `bin/rails typelizer:generate`; CI fails if the committed output is
stale.

Records use public ids (`usr_Ab12Cd`). Pundit fails closed: every action must `authorize`, every index must
`policy_scope`. Admins can impersonate users; PaperTrail records the admin.

## Checks

```sh
bin/ci
```

Runs everything GitHub runs (`config/ci.rb`): RuboCop, Prettier, svelte-check, Brakeman, dependency audits, tests
and a check that generated files are committed. Tests fail on N+1 queries and on pages over their query budget;
[docs/performance.md](docs/performance.md) explains the guardrails and how to read them. Conventions for working
in this folder are in [AGENTS.md](AGENTS.md).

## Deploy

Two Coolify services from this folder (set it as the base directory), Dockerfile build pack, same env vars
(`.env.production.example`):

1. web: `Dockerfile`, port 80, health check `GET /up`.
2. worker: `Dockerfile.worker`, no port, no health check. Runs `bin/worker`.

Secrets are ENV only. `bin/rails secret` for `SECRET_KEY_BASE`, `bin/rails db:encryption:init` for the
`ACTIVE_RECORD_ENCRYPTION_*` keys. Set `HASHID_SALT` once and never change it. Deploy web first (it runs
`db:prepare`), then the worker. `SOLID_QUEUE_IN_PUMA=1` runs jobs inside the web container if you want one service.

Uploads go to Cloudflare R2 when `R2_BUCKET` is set. Mail goes through Loops when `LOOPS_API_KEY` is set.
