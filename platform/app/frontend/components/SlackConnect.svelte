<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { connectSlack, skipSlack } from '@/routes'

  export interface SlackStatus {
    configured: boolean
    oauth_available: boolean
    connected: boolean
    ready: boolean
    linked: boolean
  }

  // The gate: projects and journals exist in Slack first, so nothing can be written here until Slack is connected
  // or skipped (then the bot posts them under the person's name).
  let { slack, returnTo }: { slack: SlackStatus; returnTo: string } = $props()
</script>

{#if !slack.ready}
  <div class="paper px-6 py-5">
    <p class="font-display text-xl text-ink">Connect Slack to start</p>
    {#if slack.oauth_available}
      <div class="mt-4 flex items-center gap-4">
        <a href={connectSlack({ query: { return_to: returnTo } }).url} class="btn-ink px-5 py-2.5"
          >Connect Slack</a
        >
        <button
          type="button"
          class="font-outfit text-sm text-ink-soft underline hover:text-ink"
          onclick={() => router.post(skipSlack().url, {}, { preserveScroll: true })}
          >Skip, post through the bot</button
        >
      </div>
    {:else}
      <p class="mt-3 font-outfit text-xs text-red-700">
        Slack sign-in is not configured on this server yet (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET).
      </p>
    {/if}
  </div>
{/if}
