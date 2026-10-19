<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
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
  <div class="glass">
    <SettingRow
      title="Connect Slack to start"
      description="Projects and journals live in Slack threads, so connect it to write here, or let the bot post them under your name."
    >
      {#snippet lead()}
        <span class="size-3 rounded-full bg-white/30" aria-hidden="true"></span>
      {/snippet}
      {#if slack.oauth_available}
        <div class="flex flex-wrap items-center gap-4">
          <button
            type="button"
            class="font-outfit text-sm text-sky-ice/60 underline hover:text-white"
            onclick={() => router.post(skipSlack().url, {}, { preserveScroll: true })}
            >Skip, post through the bot</button
          >
          <a href={connectSlack({ query: { return_to: returnTo } }).url} class="pill-cream h-11 text-base"
            >Connect Slack</a
          >
        </div>
      {/if}
    </SettingRow>
    {#if !slack.oauth_available}
      <p class="px-5 pb-4 font-outfit text-sm text-red-300 md:px-6">
        Slack sign-in is not configured on this server yet (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET).
      </p>
    {/if}
  </div>
{/if}
