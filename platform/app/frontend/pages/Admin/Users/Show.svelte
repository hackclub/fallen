<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router, useForm } from '@inertiajs/svelte'
  import RoleBadge from '@/components/RoleBadge.svelte'
  import { formatDate, formatDateTime } from '@/lib/format'
  import { adminUsers, impersonateAdminUser } from '@/routes'
  import type { AdminUserDetail } from '@/types'

  let {
    user,
    roles,
    can,
  }: { user: AdminUserDetail; roles: string[]; can: { update: boolean; impersonate: boolean } } = $props()

  // svelte-ignore state_referenced_locally
  const form = useForm({ roles: [...user.roles], is_banned: user.is_banned })

  function toggleRole(role: string) {
    form.roles = form.roles.includes(role) ? form.roles.filter((r) => r !== role) : [...form.roles, role]
  }

  function save(event: SubmitEvent) {
    event.preventDefault()
    form.transform((data) => ({ user: data })).submit(adminUsers.update(user.id), { preserveScroll: true })
  }
</script>

<svelte:head><title>{user.display_name} · Admin</title></svelte:head>

<Link href={adminUsers.index()} class="text-sm text-stone-500 hover:underline">← All users</Link>

<div class="mt-4 flex items-center gap-4">
  <img src={user.avatar} alt="" class="h-16 w-16 rounded-full bg-stone-200 object-cover" />
  <div>
    <h1 class="text-2xl font-bold">{user.display_name}</h1>
    <p class="text-sm text-stone-500">{user.email}</p>
  </div>
  <span class="ml-auto flex gap-1"
    >{#each user.roles as role (role)}<RoleBadge {role} />{/each}</span
  >
</div>

<div class="mt-6 grid gap-6 lg:grid-cols-2">
  <dl class="card grid grid-cols-2 gap-x-6 gap-y-4 text-sm">
    <div>
      <dt class="text-stone-500">Public ID</dt>
      <dd class="font-mono">{user.id}</dd>
    </div>
    <div>
      <dt class="text-stone-500">HCA ID</dt>
      <dd class="font-mono">{user.hca_id}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Slack ID</dt>
      <dd class="font-mono">{user.slack_id ?? 'none'}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Timezone</dt>
      <dd>{user.timezone}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Verification</dt>
      <dd>{user.verification_status ?? 'unknown'}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Adult</dt>
      <dd>{user.is_adult ? 'yes' : 'no'}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Last seen</dt>
      <dd>{formatDateTime(user.last_seen_at)}</dd>
    </div>
    <div>
      <dt class="text-stone-500">Joined</dt>
      <dd>{formatDate(user.created_at)}</dd>
    </div>
  </dl>

  <form onsubmit={save} class="card space-y-5 text-sm">
    <fieldset disabled={!can.update} class="space-y-5">
      <div>
        <p class="font-semibold">Roles</p>
        <div class="mt-2 flex flex-wrap gap-4">
          {#each roles as role (role)}
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                checked={form.roles.includes(role)}
                onchange={() => toggleRole(role)}
                class="rounded border-stone-300 text-hc-red focus:ring-hc-red"
              />
              {role}
            </label>
          {/each}
        </div>
        {#if form.errors.roles}<p class="mt-1 text-red-600">{form.errors.roles}</p>{/if}
      </div>

      <label class="flex items-center gap-2">
        <input
          type="checkbox"
          bind:checked={form.is_banned}
          class="rounded border-stone-300 text-hc-red focus:ring-hc-red"
        />
        <span class="font-semibold">Banned</span>
        <span class="text-stone-500">(blocks sign in and every page)</span>
      </label>

      <div class="flex items-center gap-3">
        <button type="submit" class="btn-primary" disabled={form.processing}>Save</button>
        {#if form.recentlySuccessful}<span class="text-emerald-700">Saved.</span>{/if}
        {#if !can.update}<span class="text-stone-500">You can't edit your own account.</span>{/if}
      </div>
    </fieldset>
  </form>
</div>
