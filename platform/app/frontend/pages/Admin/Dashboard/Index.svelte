<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { adminUsers } from '@/routes'

  let {
    stats,
    slack_configured,
  }: {
    stats: { users: number; admins: number; banned: number; seen_today: number }
    slack_configured: boolean
  } = $props()

  const tiles = $derived([
    { label: 'Users', value: stats.users, href: adminUsers.index() },
    { label: 'Admins', value: stats.admins, href: adminUsers.index({ query: { query: 'admin' } }) },
    { label: 'Banned', value: stats.banned, href: null },
    { label: 'Seen today', value: stats.seen_today, href: null },
  ])
</script>

<svelte:head><title>Admin · Fallen</title></svelte:head>

<h1 class="text-2xl font-bold">Dashboard</h1>

<div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
  {#each tiles as tile (tile.label)}
    <div class="card">
      <p class="text-sm text-stone-500">{tile.label}</p>
      <p class="mt-1 text-3xl font-bold tabular-nums">{tile.value}</p>
      {#if tile.href}
        <Link href={tile.href} class="mt-2 inline-block text-sm text-hc-red hover:underline">View →</Link>
      {/if}
    </div>
  {/each}
</div>

<div class="mt-8 grid gap-4 sm:grid-cols-2">
  <div class="card text-sm">
    <h2 class="font-semibold">Background jobs</h2>
    <p class="mt-1 text-stone-600">Solid Queue dashboard (Mission Control).</p>
    <a href="/admin/jobs" class="btn-secondary mt-3">Open jobs ↗</a>
  </div>
  <div class="card text-sm">
    <h2 class="font-semibold">Slack</h2>
    <p class="mt-1 text-stone-600">
      {slack_configured
        ? 'Bot token and signing secret are set.'
        : 'Set SLACK_BOT_TOKEN and SLACK_SIGNING_SECRET.'}
    </p>
  </div>
</div>
