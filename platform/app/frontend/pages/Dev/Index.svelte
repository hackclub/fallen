<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import { Link, router, useForm } from '@inertiajs/svelte'
  import { timeAgo } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import { dev, devSignInAs, devUsers, signOut } from '@/routes'
  import type { DevUser } from '@/types'

  let {
    users,
    query,
    roles,
    pets,
    hca_configured,
  }: { users: DevUser[]; query: string; roles: string[]; pets: string[]; hca_configured: boolean } = $props()

  const me = $derived(shared().auth.user)

  // Searching asks the server (it only sends the 50 most recently seen accounts), a beat after the last keystroke.
  // svelte-ignore state_referenced_locally
  let q = $state(query)
  let searchTimer: ReturnType<typeof setTimeout> | undefined
  function search() {
    clearTimeout(searchTimer)
    searchTimer = setTimeout(() => {
      router.get(dev.index(), q ? { q } : {}, {
        only: ['users', 'query'],
        preserveState: true,
        replace: true,
      })
    }, 150)
  }

  // Up and down move through the list from the search box, Enter signs in as the highlighted account.
  let highlighted = $state(0)
  $effect(() => {
    void users
    highlighted = 0
  })
  function onSearchKey(event: KeyboardEvent) {
    if (event.key === 'ArrowDown') highlighted = Math.min(highlighted + 1, users.length - 1)
    else if (event.key === 'ArrowUp') highlighted = Math.max(highlighted - 1, 0)
    else if (event.key === 'Enter' && users[highlighted]) router.visit(devSignInAs(users[highlighted].id))
    else return
    event.preventDefault()
  }

  const form = useForm({
    display_name: '',
    email: '',
    roles: ['user'] as string[],
    pet: '',
    is_adult: false,
    is_banned: false,
  })

  function toggleRole(role: string) {
    form.roles = form.roles.includes(role) ? form.roles.filter((r) => r !== role) : [...form.roles, role]
  }

  // One click: a fresh account with the defaults, as a first-time sign in would make it.
  function createDefault() {
    router.post(devUsers(), { roles: ['user'] })
  }
</script>

<svelte:head><title>Dev login · Fallen</title></svelte:head>

<div class="min-h-screen bg-sky-deep px-4 py-12 font-outfit text-sky-ice">
  <div class="mx-auto flex max-w-2xl flex-col gap-6">
    <header class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 class="text-3xl font-bold text-cream">Dev login</h1>
        <p class="mt-1 text-sm text-sky-ice/60">
          Local only. {hca_configured
            ? 'Hack Club Auth is configured too, so the real sign in still works.'
            : 'Hack Club Auth is not configured, so signing in lands here.'}
        </p>
      </div>
      {#if me}
        <div class="flex items-center gap-3 text-sm">
          <span class="text-sky-ice/60">Signed in as <b class="text-cream">{me.display_name}</b></span>
          <Link href={signOut()} as="button" class="btn border-white/15 text-sky-ice hover:bg-white/10"
            >Sign out</Link
          >
        </div>
      {/if}
    </header>

    <section class="sky-card flex flex-col gap-4">
      <div class="flex items-center justify-between gap-4">
        <h2 class="text-lg font-semibold text-cream">New account</h2>
        <button type="button" class="btn-sky-gold" onclick={createDefault} disabled={form.processing}>
          Create and sign in
        </button>
      </div>

      <details class="group">
        <summary class="cursor-pointer text-sm text-sky-ice/60 select-none hover:text-sky-ice">
          Customise roles, pet and flags
        </summary>
        <form
          class="mt-4 grid gap-4 sm:grid-cols-2"
          onsubmit={(event) => {
            event.preventDefault()
            form.submit(devUsers())
          }}
        >
          <label class="flex flex-col gap-1">
            <span class="sky-label">Name</span>
            <input
              bind:value={form.display_name}
              placeholder="Tester abc123"
              class="input border-white/15 bg-sky-night text-sky-ice"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="sky-label">Email</span>
            <input
              bind:value={form.email}
              type="email"
              placeholder="made up from the name"
              class="input border-white/15 bg-sky-night text-sky-ice"
            />
          </label>

          <div class="flex flex-col gap-1">
            <span class="sky-label">Roles</span>
            <div class="flex flex-wrap gap-2">
              {#each roles as role (role)}
                <button
                  type="button"
                  class={[
                    'badge cursor-pointer border px-3 py-1',
                    form.roles.includes(role)
                      ? 'border-sky-gold bg-sky-gold text-sky-night'
                      : 'border-white/15 text-sky-ice/70 hover:bg-white/10',
                  ]}
                  aria-pressed={form.roles.includes(role)}
                  disabled={role === 'user'}
                  onclick={() => toggleRole(role)}
                >
                  {role}
                </button>
              {/each}
            </div>
          </div>
          <label class="flex flex-col gap-1">
            <span class="sky-label">Pet</span>
            <select bind:value={form.pet} class="input border-white/15 bg-sky-night text-sky-ice">
              <option value="">None yet (hasn't onboarded)</option>
              {#each pets as pet (pet)}
                <option value={pet}>{pet}</option>
              {/each}
            </select>
          </label>

          <div class="flex flex-wrap gap-4 text-sm sm:col-span-2">
            <label class="flex items-center gap-2">
              <input type="checkbox" bind:checked={form.is_adult} class="rounded" /> Adult (18+)
            </label>
            <label class="flex items-center gap-2">
              <input type="checkbox" bind:checked={form.is_banned} class="rounded" /> Banned
            </label>
          </div>

          {#if Object.keys(form.errors).length}
            <p class="text-sm text-hc-red sm:col-span-2">{Object.values(form.errors).join(', ')}</p>
          {/if}

          <div class="sm:col-span-2">
            <button type="submit" class="btn-sky-gold" disabled={form.processing}>Create this account</button>
          </div>
        </form>
      </details>
    </section>

    <section class="sky-card flex flex-col gap-4">
      <div class="flex items-center justify-between gap-4">
        <h2 class="text-lg font-semibold text-cream">Existing accounts</h2>
        <span class="sky-label">↑ ↓ to pick, Enter to sign in</span>
      </div>
      <!-- svelte-ignore a11y_autofocus -->
      <input
        bind:value={q}
        oninput={search}
        onkeydown={onSearchKey}
        autofocus
        type="search"
        placeholder="Search by name, email or Slack ID"
        aria-label="Search accounts"
        class="input border-white/15 bg-sky-night text-sky-ice"
      />

      {#if users.length === 0}
        <p class="text-sm text-sky-ice/60">
          {q ? `No accounts match "${q}".` : 'No accounts yet. Make one above, or run bin/rails db:seed.'}
        </p>
      {:else}
        <ul class="-mx-2 flex flex-col">
          {#each users as user, i (user.id)}
            <li>
              <Link
                href={devSignInAs(user.id)}
                class={[
                  'flex items-center gap-3 rounded-xl px-2 py-2 transition',
                  i === highlighted ? 'bg-white/10' : 'hover:bg-white/5',
                ]}
                onmouseenter={() => (highlighted = i)}
              >
                <span
                  class="grid size-9 shrink-0 place-items-center rounded-full bg-sky-night font-bold text-sky-gold"
                  aria-hidden="true">{user.display_name.charAt(0).toUpperCase()}</span
                >
                <span class="min-w-0 flex-1">
                  <span class="flex flex-wrap items-center gap-1.5">
                    <span class="truncate font-semibold text-cream">{user.display_name}</span>
                    {#if me?.id === user.id}<span class="badge bg-green/20 text-green">you</span>{/if}
                    {#each user.roles.filter((r) => r !== 'user') as role (role)}
                      <span class="badge bg-sky-gold/20 text-sky-gold">{role}</span>
                    {/each}
                    {#if user.is_banned}<span class="badge bg-hc-red/20 text-hc-red">banned</span>{/if}
                    {#if user.is_adult}<span class="badge bg-white/10">18+</span>{/if}
                    {#if !user.pet}<span class="badge bg-white/10">no pet</span>{/if}
                  </span>
                  <span class="block truncate text-xs text-sky-ice/50">{user.email}</span>
                </span>
                <span class="shrink-0 text-xs text-sky-ice/40">
                  {user.last_seen_at ? `seen ${timeAgo(user.last_seen_at)}` : 'never seen'}
                </span>
              </Link>
            </li>
          {/each}
        </ul>
      {/if}
    </section>

    <section class="text-xs text-sky-ice/50">
      <p class="mb-1 sky-label">From a script or bookmark</p>
      <code class="block">/dev/sign_in_as/&lt;email, usr_ id or id&gt;</code>
      <code class="block">/dev/sign_in_as/new?roles[]=admin&amp;pet=lulu&amp;display_name=Ada</code>
    </section>
  </div>
</div>
