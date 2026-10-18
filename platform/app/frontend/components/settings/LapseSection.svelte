<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { LapseStatus } from '@/components/LapsePicker.svelte'
  import HoldButton from '@/components/settings/HoldButton.svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import { connectLapse, disconnectLapse, settings } from '@/routes'

  let { lapse }: { lapse: LapseStatus } = $props()
</script>

{#if lapse.connected}
  <SettingRow
    title="Connected"
    description="When you journal, pick a timelapse and its recorded time becomes your hours."
  >
    {#snippet lead()}
      <span class="relative flex size-3" aria-hidden="true">
        <span class="absolute inset-0 animate-ping rounded-full bg-mint/60 motion-reduce:hidden"></span>
        <span class="relative size-3 rounded-full bg-mint shadow-[0_0_10px_var(--color-mint)]"></span>
      </span>
    {/snippet}
  </SettingRow>
  <SettingRow
    title="Reconnect Lapse"
    description="Sign in again to switch Lapse accounts or renew access. Lapse asks every 30 days."
  >
    <a
      href={connectLapse({ query: { return_to: settings.show().url } }).url}
      class="pill-cream h-11 text-base">Reconnect</a
    >
  </SettingRow>
  <SettingRow title="Disconnect Lapse" description="Journals you already wrote keep their timelapses.">
    <HoldButton
      label="Hold to disconnect"
      done="Disconnecting"
      onconfirm={() => router.visit(disconnectLapse())}
    />
  </SettingRow>
{:else}
  <SettingRow
    title="Not connected"
    description="Record your sessions on Lapse, then pick a timelapse when you journal instead of typing your hours."
  >
    {#snippet lead()}
      <span class="size-3 rounded-full bg-white/30" aria-hidden="true"></span>
    {/snippet}
    <a
      href={connectLapse({ query: { return_to: settings.show().url } }).url}
      class="pill-cream h-11 text-base">Connect Lapse</a
    >
  </SettingRow>
{/if}
