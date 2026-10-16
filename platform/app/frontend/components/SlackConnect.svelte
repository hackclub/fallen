<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { connectSlack, disconnectSlack } from '@/routes'

  export interface SlackStatus {
    configured: boolean
    oauth_available: boolean
    connected: boolean
    linked: boolean
  }

  // The gate: projects and journals exist in Slack first, so nothing can be written here until Slack is connected.
  let {
    slack,
    returnTo,
    compact = false,
  }: { slack: SlackStatus; returnTo: string; compact?: boolean } = $props()
</script>

{#if slack.connected}
  {#if !compact}
    <p class="font-outfit text-xs text-sky-ice/50">
      Slack connected. Journals you write here post to your thread as you.
      <button type="button" class="underline hover:text-white" onclick={() => router.visit(disconnectSlack())}
        >Disconnect</button
      >
    </p>
  {/if}
{:else}
  <div class="paper px-6 py-5">
    <p class="font-display text-xl text-ink">Connect Slack to start</p>
    <p class="mt-1 max-w-md font-outfit text-sm text-ink-soft">
      Your project lives as a thread in the journals channel and every journal is a reply in it, posted as
      you.
    </p>
    {#if slack.oauth_available}
      <a href={connectSlack({ query: { return_to: returnTo } }).url} class="btn-ink mt-4 px-5 py-2.5"
        >Connect Slack</a
      >
    {:else}
      <p class="mt-3 font-outfit text-xs text-red-700">
        Slack sign-in is not configured on this server yet (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET).
      </p>
    {/if}
  </div>
{/if}
