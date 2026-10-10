<script lang="ts">
  import type { UserProfile } from '@/types'
  import { formatDate } from '@/lib/format'
  import RoleBadge from '@/components/RoleBadge.svelte'

  let { user, slack_connected }: { user: UserProfile; slack_connected: boolean } = $props()
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

<div class="grid gap-6 md:grid-cols-[1fr_320px]">
  <div class="card">
    <div class="flex items-center gap-4">
      <img src={user.avatar} alt="" class="h-16 w-16 rounded-full bg-stone-200 object-cover" />
      <div>
        <h1 class="text-2xl font-bold">{user.display_name}</h1>
        <p class="text-sm text-stone-500">{user.email}</p>
      </div>
    </div>

    <dl class="mt-6 grid grid-cols-2 gap-x-6 gap-y-4 text-sm">
      <div>
        <dt class="text-stone-500">Public ID</dt>
        <dd class="font-mono">{user.id}</dd>
      </div>
      <div>
        <dt class="text-stone-500">Roles</dt>
        <dd class="flex gap-1">
          {#each user.roles as role (role)}<RoleBadge {role} />{/each}
        </dd>
      </div>
      <div>
        <dt class="text-stone-500">Slack</dt>
        <dd class="font-mono">{user.slack_id ?? 'not linked'}</dd>
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
        <dt class="text-stone-500">Joined</dt>
        <dd>{formatDate(user.created_at)}</dd>
      </div>
    </dl>
  </div>

  <aside class="card space-y-3 text-sm">
    <h2 class="font-semibold">Slack bot</h2>
    {#if slack_connected}
      <p class="text-stone-600">Connected. Try <code>/ping</code> or @mention the bot in Slack.</p>
    {:else}
      <p class="text-stone-600">
        Not configured. Run <code>bin/slack-manifest --socket-mode</code>, create the app, then fill in the
        <code>SLACK_*</code> variables.
      </p>
    {/if}
  </aside>
</div>
