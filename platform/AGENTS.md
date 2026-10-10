# Working on the platform

Rails 8.1 (Ruby 3.4) + Inertia + Svelte 5 + Tailwind 4, single PostgreSQL database. Read README.md for the layout.

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
- Styling is Tailwind 4; reusable classes are `@utility` blocks in `app/frontend/entrypoints/application.css`.
- No comments that restate the code. Private methods at the bottom of the class.

## Before you finish

```sh
bin/rubocop -f github && bin/brakeman --no-pager && bin/rails test
npm run check && npm run format:check
```

Flag pre-existing failures you did not cause rather than fixing unrelated code.
