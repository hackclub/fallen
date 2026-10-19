<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { SlackStatus } from '@/components/SlackConnect.svelte'
  import HoldButton from '@/components/settings/HoldButton.svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import { connectSlack, disconnectSlack, settings } from '@/routes'

  let { slack }: { slack?: SlackStatus } = $props()
</script>

{#if !slack}
  <div class="space-y-3 px-5 py-4 md:px-6" aria-busy="true">
    <div class="h-5 w-48 animate-pulse rounded bg-white/10"></div>
    <div class="h-4 w-2/3 animate-pulse rounded bg-white/10"></div>
  </div>
{:else if slack.connected}
  <SettingRow title="Connected" description="Journals you write here post to your project's thread as you.">
    {#snippet lead()}
      <span class="relative flex size-3" aria-hidden="true">
        <span class="absolute inset-0 animate-ping rounded-full bg-mint/60 motion-reduce:hidden"></span>
        <span class="relative size-3 rounded-full bg-mint shadow-[0_0_10px_var(--color-mint)]"></span>
      </span>
    {/snippet}
  </SettingRow>
  <SettingRow title="Disconnect Slack" description="Journals will post through the bot instead.">
    <HoldButton
      label="Hold to disconnect"
      done="Disconnecting"
      onconfirm={() => router.visit(disconnectSlack())}
    />
  </SettingRow>
{:else}
  <SettingRow
    title="Not connected"
    description={slack.ready
      ? "Fallen's bot posts your journals to your project's thread under your name. Connect Slack to post them as you."
      : "Connect Slack to write journals. They post to your project's thread as you."}
  >
    {#snippet lead()}
      <span class="size-3 rounded-full bg-white/30" aria-hidden="true"></span>
    {/snippet}
    {#if slack.oauth_available}
      <a
        href={connectSlack({ query: { return_to: settings.show().url } }).url}
        class="pill-cream h-11 text-base">Connect Slack</a
      >
    {/if}
  </SettingRow>
  {#if !slack.oauth_available}
    <p class="px-5 py-4 font-outfit text-sm text-red-300 md:px-6">
      Slack sign-in is not configured on this server yet (SLACK_CLIENT_ID / SLACK_CLIENT_SECRET).
    </p>
  {/if}
{/if}
