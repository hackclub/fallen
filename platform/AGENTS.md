# Working on the platform

Rails 8.1 (Ruby 3.4) + Inertia + Svelte 5 + Tailwind 4, one PostgreSQL database. README.md has setup and the Slack
bot; docs/performance.md has the reasoning behind the performance rules below.

Every Hack Club program app starts fast and ends up taking seconds per page. This one has guardrails that fail the
build instead. Work with them: when a check fails, fix the cause, never the check.

## Where things go

| Thing | Place | Rule |
| --- | --- | --- |
| HTTP action | `app/controllers` | Thin: load, authorize, call one method, render. `admin/` is admin-only. |
| Business logic | `app/models` | Models own their rules (`Journal#duration=`, `Project#discard`). |
| Integrations | `app/services` | One module per outside system (`HCA`, `SlackMessaging`). No `FooService` classes. |
| Slow or external work | `app/jobs` | Anything that calls Slack, HCA, email or another HTTP API. Never in a request. |
| Slack handlers | `app/bot` | One class per command/event/action/view, found by name (README.md). |
| What the browser sees | `app/serializers` | Alba. Admin-only fields in `Admin*Serializer`s only. |
| Who may do what | `app/policies` | Pundit, fails closed. |
| Pages | `app/frontend/pages/<Controller>/<Action>.svelte` | One page per action, lazy-loaded chunk. |
| Shared UI | `app/frontend/components` | `admin/ui` is vendored shadcn-svelte: regenerate, don't hand-edit. |
| Reusable CSS | `@utility` blocks in `app/frontend/entrypoints/application.css` | |
| Framework code | `lib/` | `slack_bot/` and `constraints/`. Only code with no app knowledge. |

A file over ~200 lines, a model with ten `has_many`s, or a `lib/` folder with app logic is a signal to split by
domain, not to keep going.

## Conventions

- Keep changes small and consistent with neighbouring code. Prefer `bin/rails generate` for boilerplate, then edit it.
- Everything passed to `render inertia:` is visible in the browser. Props come from Alba serializers in `app/serializers` (`UserSerializer.render(user)`); never pass ActiveRecord objects. Typelizer regenerates `app/frontend/types/serializers` and `app/frontend/routes` in development; commit the output (CI checks it is current).
- Authorization is Pundit (`app/policies`) and fails closed: `ApplicationController` verifies `authorize` ran on every action and `policy_scope` on every `index`. Controllers without an index action need both `skip_after_action :verify_authorized` and `skip_after_action :verify_policy_scoped` blanket-style (Rails 8.1 raises on `only: :index` when the action is missing). Relaxing directives (`allow_unauthenticated_access`, `skip_before_action`, `skip_after_action`) take `only:`, never `except:`, and carry a short comment saying why.
- Least privilege: add the narrowest rule that makes the feature work. Admin-only data (email, HCA id) goes in `Admin*Serializer`s only.
- Records expose `public_id` (`usr_…`) to the frontend and in URLs, never the integer id. Look records up with `find_by_public_id!`.
- Soft delete with `Discardable` (`kept`/`discarded` scopes). Audited models use `has_paper_trail`.
- Long or external work (Slack API, HCA, email) goes in a job under `app/jobs` (Solid Queue). Queues: `realtime`, `slack`, `default`, `background`.
- Slack bot handlers live in `app/bot` and are found by name: `/foo` -> `FooCommand`, event `foo_bar` -> `FooBarEvent`, action_id `foo` -> `FooAction`, view callback_id `foo` -> `FooView`, shortcut `foo` -> `FooShortcut`. Framework is `lib/slack_bot`.
- Frontend pages are `app/frontend/pages/<Controller>/<Action>.svelte` (Svelte 5 runes). Shared props come from `shared()` in `app/frontend/lib/shared.svelte.ts`; prop types from `@/types`. URLs always come from the generated helpers in `@/routes` (`adminUser(id)`, `adminUsers.index()`), which `Link`, `router.visit` and `useForm().submit` accept directly. Never hand-write a path string.
- Impersonation: `current_user` is who the page is for, `true_user` is the human at the keyboard. Audit trails and permission checks that concern the admin use `true_user`.
- Program numbers (XP per hour, hour thresholds, dates) are not settled (`program/the-plan.md`). When one lands in code it goes in one named constant, never a literal spread across files.
- No comments that restate the code. Private methods at the bottom of the class.

## Performance rules

These are enforced, not aspirational. The mechanism is in brackets.

1. **No N+1 queries.** Tests fail on a lazy-loaded association inside a loop and on an unused `includes` [Bullet
   raises in test]. Preload what the serializer reads (`includes(:user)`, `includes(images_attachments: :blob)`).
2. **Every page has a query budget** in `test/controllers/query_budget_test.rb` [`assert_query_budget`]. A new
   page gets a budget. A page over budget gets fixed, not a bigger number. Counts must not grow with the data.
3. **No unbounded lists.** Anything not scoped to one person's own records is paginated with `pagy` and rendered
   through `deferred_table`. Aggregates over a list are one grouped query passed to the serializer as params
   (`ProjectSerializer` takes `totals:` and `counts:`), never a per-row `count`/`sum`.
4. **The page shell renders from cheap queries.** Counts, charts, tables and anything over a few milliseconds are
   `InertiaRails.defer` props, so the person sees the page and the data streams in.
5. **Nothing in a request waits on the network.** Slack, HCA, email and HTTP go in a job. `inertia_share` runs on
   every request, so it holds only the session user and flash.
6. **Every statement finishes in 5 seconds or is killed** [`statement_timeout` in `config/database.yml`]. A page that
   needs more has a missing index or belongs in a job.
7. **Indexes come with the column.** Every column in a `where`, `order` or `join` is indexed, every foreign key has
   one. Migrations that lock a table are refused [`strong_migrations`]; read its message and do what it says.
8. **Frontend stays small.** Pages are lazy chunks [`import.meta.glob` in `entrypoints/inertia.ts`]; a heavy
   library (charts, editors) is imported dynamically from the one place that uses it. Before adding an npm
   package, check its size and whether thirty lines would do: the landing effects (`components/shaders/`) are
   plain WebGL2 because Three.js was 200 KB gzipped to draw two sets of points. After adding one, run
   `bin/vite build` and look at the chunk sizes.
9. **Caching is the last tool, not the first.** A cache hides an N+1 until it expires. Fix the query; cache only a
   result that is expensive after it is already efficient, with a key that changes when the data does.

To see what a page costs in development: the rack-mini-profiler badge (top left) lists every query and its time;
Bullet writes N+1 warnings to the browser console. In production, `pg_stat_statements` rows carry the
controller#action that ran them.

## Adding a feature

1. Migration (`strong_migrations` will tell you if it locks), model with validations and scopes, policy, policy test.
2. Serializer with only the fields the page needs; `bin/rails typelizer:generate` and commit the output.
3. Controller action: `authorize`, preload, defer the slow props, render. Controller test, plus a line in
   `query_budget_test.rb`.
4. Page under `pages/`, URLs from `@/routes`, types from `@/types`.
5. If it touches another system: a job, and a test with `with_fake_slack` or a stubbed client.
6. If it stores user data: update `docs/privacy.md` and `PrivacyRequest`.
7. `bin/ci`.

## Before you finish

```sh
bin/ci
```

It runs RuboCop, Prettier, svelte-check, Brakeman, dependency audits, the test suite and the generated-file check,
the same way GitHub does. Flag pre-existing failures you did not cause rather than fixing unrelated code.
