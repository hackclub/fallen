# Performance

## Why this document exists

Hack Club program apps follow a pattern. They launch fast. Features get added quickly, often by people and agents
who never see the app with real data. Nobody notices a page doing one query per row when there are twelve rows.
Six weeks in there are two thousand rows, pages take ten seconds, and the fix is a rewrite nobody has time for.

The rules in `AGENTS.md` exist so the build fails on day one instead. This page explains what each guardrail does,
how to read it when it fires, and how to find out why a page is slow.

## What is enforced, and where

| Guardrail | Mechanism | Where |
| --- | --- | --- |
| N+1 queries and unused preloads fail tests | Bullet with `raise = true` | `config/environments/test.rb`, hooks in `test/test_helper.rb` |
| Each page has a maximum query count | `assert_query_budget` | `test/controllers/query_budget_test.rb` |
| No statement runs longer than 5s (web and jobs) | PostgreSQL `statement_timeout`, `lock_timeout` | `config/database.yml`, `DB_STATEMENT_TIMEOUT` |
| Migrations cannot lock a table or add an index without `CONCURRENTLY` | strong_migrations | `config/initializers/strong_migrations.rb` |
| Slow queries in production are attributable | query log tags (`/*controller:…,action:…*/`) | `config/environments/production.rb` |
| Pages and heavy libraries are separate JS chunks | lazy `import.meta.glob`, dynamic `import()` | `app/frontend/entrypoints/inertia.ts`, `components/shaders/LandingScene.svelte` |
| Slow props do not block the page | `InertiaRails.defer` | `Admin::ApplicationController#deferred_table` and friends |
| External calls never happen in a request | Jobs on Solid Queue | `app/jobs` |
| One command runs every check | `bin/ci` | `config/ci.rb`, `.github/workflows/ci.yml` |

## Reading a failure

**Bullet: `USE eager loading detected  Journal => [:user]`.** Something looped over journals and read `.user` on
each. Add `includes(:user)` to the query that loaded the journals. If the loop is in a serializer, the preload
goes in the controller that calls the serializer. If the loop is a validation (a `discard` over many records), the
preload goes on the `find_each` scope.

**Bullet: `AVOID eager loading detected`.** An `includes` nobody reads. Remove it. Active Storage's
`with_attached_images` preloads variants and previews the pages do not use, so prefer
`includes(images_attachments: :blob)`.

**`Expected at most 8 queries, ran 14`.** The test prints every query. Look for repeats that differ only in an id:
that is an N+1 Bullet did not classify (often a `count` or `sum` per row). Replace with one grouped query and pass
the result to the serializer as params. If the page genuinely needs more queries because it shows more, raise the
budget in the same commit that adds the feature and say why in the commit message.

**`PG::QueryCanceled: canceling statement due to statement timeout`.** A query took over 5 seconds. Run it with
`EXPLAIN ANALYZE` in `bin/rails dbconsole`. A sequential scan on a big table means a missing index. A query that is
correct and still slow (a report over everything) belongs in a job that writes its result somewhere a page can read
cheaply.

**strong_migrations refused a migration.** The message names the safe alternative (`algorithm: :concurrently`,
`disable_ddl_transaction!`, separate migrations for add-column and backfill). Do that. `safety_assured` is for a
table you know is tiny, with a comment saying so.

## Finding out why a page is slow

In development, the rack-mini-profiler badge at the top left of every page lists the request's queries with their
timings and call sites. Click it after an Inertia visit too; XHR requests are added to it. `?pp=help` lists its
other modes, including flame graphs.

In production:

- `/admin/insights` charts throughput and median/p95 response times over the last hour to 30 days, lists the
  controller actions and jobs that cost the most time in total, and drills into one to show its slowest requests.
  Start here to find which page or job is slow. It reads the ActiveInsights tables that `InsightsBuffer` fills; rows
  older than 30 days are deleted nightly.
- Sentry traces every request and job (not `/up`) with a span per query, and profiles them, so a slow trace shows
  the Ruby stack that spent the time. The browser side traces page loads, Inertia visits and Web Vitals, joined to
  the Rails trace. `SENTRY_TRACES_SAMPLE_RATE` and `SENTRY_PROFILES_SAMPLE_RATE` turn these down when traffic grows.
- The database's `pg_stat_statements` view (Orchard's query stats) shows the most expensive statements over time,
  and every row's comment says which controller action or job ran it.

A quick local check that scales the data: `bin/rails db:seed` creates a handful of records; the query budget test
with fixtures catches per-row patterns because the fixtures have more than one project and journal per person.
If a page's count stays flat when you add a fixture, it is fine.

## Measuring the whole stack

`Completed 200 OK in 5ms` is the controller and view only. Middleware runs before and after it: in October 2026
the landing page logged 1ms and took 85ms, all of it in Rack::Attack counting requests in Solid Cache (a locked
row write and a commit per request, twice because the gem's railtie and `config/application.rb` had both added
the middleware) and in Sentry tracing. Counts live in memory now and the middleware is added once. To measure a
request end to end on a pod, call the app in-process and time it:

```ruby
# bin/rails runner, on a production pod
env = Rack::MockRequest.env_for("https://#{ENV["APP_HOST"]}/home", "HTTP_HOST" => ENV["APP_HOST"], "REMOTE_ADDR" => "203.0.113.9", "HTTP_COOKIE" => cookie)
ActiveRecord::Base.transaction { status, _, body = Rails.application.call(env); body.close; raise ActiveRecord::Rollback }
```

Toggle a suspect (`Rack::Attack.enabled = false`, `Sentry.configuration.traces_sampler = ->(_) { 0.0 }`) and time it
again; the difference is that layer's cost. A sampled Sentry trace costs about 40ms, so keep
`SENTRY_TRACES_SAMPLE_RATE` low once traffic is real.

## Patterns that keep pages fast

- **Preload at the query.** `Project.kept.includes(:user)` in the controller, not `project.user` fixes in the view.
- **Aggregate in one query.** `Journal.kept.where(project_id: ids).group(:project_id).sum(:duration_minutes)`
  returns a hash; the serializer looks rows up in it. Never `projects.map(&:total_minutes)`.
- **Paginate anything that can grow.** `pagy(scope)`, 25 a page, through `deferred_table`.
- **Defer anything not needed for first paint.** Counts, charts, tables, sidebar pills. Not a few indexed queries
  over one person's own rows: a deferred prop is another request, and a round trip is 100-300ms for most people
  (the server is in Germany, behind Cloudflare), far more than the queries.
- **Count round trips, not just queries.** Every request costs the round trip before the server does anything.
  Page chunks are preloaded with the HTML (`ApplicationHelper#inertia_page_preload_tags`), the nav prefetches a
  page's props on hover, and the timer, fonts and chunks are served from the same origin or the Cloudflare edge.
- **Push external work to jobs** and tell the person it is happening ("Posting to Slack…") rather than waiting.
- **Keep the shared props cheap.** `inertia_share` runs on every request.
- **Keep the entry bundle small.** Pages are lazy. Anything over ~100 KB minified gets its own dynamic import.
- **Cache last.** Solid Cache is there for results that are already efficient and still expensive.

## Capacity

Puma runs `WEB_CONCURRENCY` processes of `RAILS_MAX_THREADS` threads each; the connection pool follows the thread
count. Jobs run in a separate container (`Dockerfile.worker`) so a Slack outage cannot starve web requests.
