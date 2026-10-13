<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import type { UserProfile } from '@/types'
  import { formatDate } from '@/lib/format'

  let { user, slack_connected }: { user: UserProfile; slack_connected: boolean } = $props()

  const details = $derived([
    { label: 'Public ID', value: user.id, mono: true },
    { label: 'Slack', value: user.slack_id ?? 'not linked', mono: true },
    { label: 'Timezone', value: user.timezone, mono: false },
    { label: 'Verification', value: user.verification_status ?? 'unknown', mono: false },
    { label: 'Joined', value: formatDate(user.created_at), mono: false },
  ])
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

<div class="grid gap-6 md:grid-cols-[1fr_320px]">
  <section class="sky-card">
    <div class="flex items-center gap-4">
      <img src={user.avatar} alt="" class="h-16 w-16 rounded-full bg-sky-night object-cover" />
      <div>
        <h1 class="font-display text-2xl text-white">{user.display_name}</h1>
        <p class="font-outfit text-sm text-sky-ice/60">{user.email}</p>
      </div>
    </div>

    <dl class="mt-6 grid grid-cols-2 gap-x-6 gap-y-4 border-t border-white/10 pt-6 text-sm">
      <div>
        <dt class="sky-label">Roles</dt>
        <dd class="mt-1 flex flex-wrap gap-1.5">
          {#each user.roles as role (role)}
            <span class="badge border border-white/15 font-outfit text-sky-ice">{role}</span>
          {/each}
        </dd>
      </div>
      {#each details as detail (detail.label)}
        <div>
          <dt class="sky-label">{detail.label}</dt>
          <dd class="mt-1 text-white {detail.mono ? 'font-mono text-xs' : 'font-outfit'}">{detail.value}</dd>
        </div>
      {/each}
    </dl>
  </section>

  <aside class="sky-card space-y-3 text-sm">
    <h2 class="font-display text-lg text-white">Slack bot</h2>
    {#if slack_connected}
      <p class="font-outfit text-sky-ice/70">
        Connected. Try <code>/ping</code> or @mention the bot in Slack.
      </p>
    {:else}
      <p class="font-outfit text-sky-ice/70">
        Not configured. Run <code>bin/slack-manifest --socket-mode</code>, create the app, then fill in the
        <code>SLACK_*</code> variables.
      </p>
    {/if}
  </aside>
</div>
