<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import Pagination from '@/components/Pagination.svelte'
  import RoleBadge from '@/components/RoleBadge.svelte'
  import { formatDate, formatDateTime } from '@/lib/format'
  import { adminUser, adminUsers } from '@/routes'
  import type { AdminUser, Pagy } from '@/types'

  let { users, pagy, query }: { users: AdminUser[]; pagy: Pagy; query: string } = $props()

  // svelte-ignore state_referenced_locally
  let search = $state(query)

  function submit(event: SubmitEvent) {
    event.preventDefault()
    router.get(adminUsers.index().url, search ? { query: search } : {}, { preserveState: true })
  }
</script>

<svelte:head><title>Users · Admin</title></svelte:head>

<div class="flex items-center justify-between gap-4">
  <h1 class="text-2xl font-bold">Users</h1>
  <form onsubmit={submit} class="flex gap-2">
    <input type="search" bind:value={search} placeholder="Search name, email, Slack ID" class="input w-64" />
    <button type="submit" class="btn-secondary">Search</button>
  </form>
</div>

<div class="card mt-6 overflow-x-auto p-0">
  <table class="w-full text-sm">
    <thead class="bg-stone-50 text-left text-xs text-stone-500 uppercase">
      <tr>
        <th class="px-4 py-3">User</th>
        <th class="px-4 py-3">Roles</th>
        <th class="px-4 py-3">Last seen</th>
        <th class="px-4 py-3">Joined</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-stone-100">
      {#each users as user (user.id)}
        <tr class="hover:bg-stone-50">
          <td class="px-4 py-3">
            <Link href={adminUser(user.id)} class="flex items-center gap-3">
              <img src={user.avatar} alt="" class="h-8 w-8 rounded-full bg-stone-200 object-cover" />
              <span>
                <span class="block font-medium">{user.display_name}</span>
                <span class="block text-xs text-stone-500">{user.email}</span>
              </span>
              {#if user.is_banned}<span class="badge bg-red-100 text-red-700">banned</span>{/if}
            </Link>
          </td>
          <td class="px-4 py-3"
            ><span class="flex gap-1"
              >{#each user.roles as role (role)}<RoleBadge {role} />{/each}</span
            ></td
          >
          <td class="px-4 py-3 text-stone-600">{formatDateTime(user.last_seen_at)}</td>
          <td class="px-4 py-3 text-stone-600">{formatDate(user.created_at)}</td>
        </tr>
      {:else}
        <tr><td colspan="4" class="px-4 py-8 text-center text-stone-500">No users found.</td></tr>
      {/each}
    </tbody>
  </table>
</div>

<Pagination {pagy} />
