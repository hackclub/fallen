<script lang="ts" module>
  import type { LapseTimelapse } from '@/types'

  export type LapseStatus = {
    configured: boolean
    connected: boolean
    synced_at: string | null
    timelapses?: LapseTimelapse[]
  }
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { untrack } from 'svelte'
  import { connectLapse, lapseSync } from '@/routes'

  let {
    lapse,
    current = [],
    selected = $bindable(),
    returnTo,
    error,
  }: {
    lapse?: LapseStatus | null
    // The timelapses already on the journal being edited, which the unclaimed list leaves out.
    current?: LapseTimelapse[]
    selected: string[]
    returnTo: string
    error?: string
  } = $props()

  const STALE_MS = 60_000
  const POLL_MS = 2_000
  const POLL_TRIES = 8

  let syncing = $state(false)
  let syncFailed = $state(false)

  const options = $derived([
    ...current,
    ...(lapse?.timelapses ?? []).filter((t) => !current.some((c) => c.id === t.id)),
  ])
  // Same decimal hours as Duration.format on the server, which does the real sum.
  const totalMinutes = $derived(
    options.filter((t) => selected.includes(t.id)).reduce((sum, t) => sum + t.duration_minutes, 0),
  )
  const totalText = $derived(`${Math.round((totalMinutes / 60) * 100) / 100}h`)

  // Lapse is only asked when the composer opens or on Refresh; the list itself comes from Fallen's copy.
  function sync() {
    if (!lapse?.connected || syncing) return
    const before = lapse.synced_at
    syncing = true
    syncFailed = false
    let tries = 0
    const poll = () => {
      if (lapse?.synced_at !== before || !lapse?.connected) return (syncing = false)
      if (++tries > POLL_TRIES) {
        syncing = false
        syncFailed = true
        return
      }
      setTimeout(() => router.reload({ only: ['lapse'], onFinish: poll }), POLL_MS)
    }
    router.post(
      lapseSync(),
      {},
      { only: ['lapse'], preserveScroll: true, preserveState: true, onFinish: poll },
    )
  }

  // Once the deferred prop arrives, refresh a stale copy so a timelapse just published shows up.
  let checkedOnOpen = false
  $effect(() => {
    if (checkedOnOpen || !lapse) return
    checkedOnOpen = true
    const age = lapse.synced_at ? Date.now() - Date.parse(lapse.synced_at) : Infinity
    if (age > STALE_MS) untrack(sync)
  })

  function toggle(timelapse: LapseTimelapse) {
    if (timelapse.unusable_reason) return
    selected = selected.includes(timelapse.id)
      ? selected.filter((id) => id !== timelapse.id)
      : [...selected, timelapse.id]
  }
</script>

{#if lapse === undefined}
  <div aria-busy="true">
    <div class="skeleton-ink h-6 w-28"></div>
    <div class="mt-2 skeleton-ink h-4 w-full"></div>
  </div>
{:else if lapse?.configured}
  <div>
    <div class="flex items-baseline justify-between gap-2">
      <p class="font-display text-lg text-ink">
        Timelapses <span class="font-outfit text-xs whitespace-nowrap text-ink-soft"
          >(helps you not get deflated)</span
        >
      </p>
      {#if lapse.connected}
        <button
          type="button"
          onclick={sync}
          disabled={syncing}
          class="font-outfit text-xs text-ink-soft underline hover:text-ink disabled:no-underline"
        >
          {syncing ? 'Checking Lapse…' : 'Refresh'}
        </button>
      {/if}
    </div>

    {#if !lapse.connected}
      <p class="mb-2 font-outfit text-xs text-ink-soft">
        Recorded the session on Lapse? Connect it and pick the timelapses to back up your hours.
      </p>
      <a
        href={connectLapse({ query: { return_to: returnTo } }).url}
        class="btn-paper block py-1.5 text-center">Connect Lapse</a
      >
    {:else}
      <p class="mb-2 font-outfit text-xs text-ink-soft">
        Pick every one from this session. They back up the hours you log.
        {#if syncFailed}<span class="text-amber-700">Couldn't reach Lapse just now.</span>{/if}
      </p>
      {#if options.length === 0}
        <p class="rounded-lg bg-paper-well px-3 py-2 font-outfit text-xs text-ink-soft">
          {syncing ? 'Looking for your timelapses…' : 'No timelapses yet.'}
          <a href="https://lapse.hackclub.com" target="_blank" rel="noopener" class="underline hover:text-ink"
            >Record one on Lapse ↗</a
          >
        </p>
      {:else}
        <ul class="max-h-64 space-y-1.5 overflow-y-auto" aria-label="Timelapses">
          {#each options as timelapse (timelapse.id)}
            {@const active = selected.includes(timelapse.id)}
            <li>
              <button
                type="button"
                role="checkbox"
                aria-checked={active}
                disabled={Boolean(timelapse.unusable_reason)}
                title={timelapse.unusable_reason ? `This timelapse ${timelapse.unusable_reason}` : undefined}
                onclick={() => toggle(timelapse)}
                class={[
                  'flex w-full items-center gap-2.5 rounded-lg border-2 p-1.5 text-left transition-colors',
                  active ? 'border-ink bg-paper-well' : 'border-transparent hover:bg-paper-well/60',
                  timelapse.unusable_reason && 'cursor-not-allowed opacity-50 hover:bg-transparent',
                ]}
              >
                <span class="aspect-video w-16 shrink-0 overflow-hidden rounded bg-ink/10">
                  {#if timelapse.thumbnail_url}
                    <img
                      src={timelapse.thumbnail_url}
                      alt=""
                      loading="lazy"
                      class="h-full w-full object-cover"
                    />
                  {/if}
                </span>
                <span class="min-w-0 flex-1 font-outfit text-xs">
                  <span class="block truncate text-sm text-ink">{timelapse.name || 'Untitled timelapse'}</span
                  >
                  <span class="text-ink-soft">
                    {timelapse.unusable_reason
                      ? timelapse.unusable_reason.replace(/^is /, '')
                      : timelapse.duration_text}
                  </span>
                </span>
              </button>
            </li>
          {/each}
        </ul>
        {#if selected.length > 0}
          <p class="mt-2 font-outfit text-sm text-ink" aria-live="polite">
            {totalText} from {selected.length}
            {selected.length === 1 ? 'timelapse' : 'timelapses'}
          </p>
        {/if}
      {/if}
    {/if}
    {#if error}<p class="mt-1 font-outfit text-xs text-red-700">{error}</p>{/if}
  </div>
{/if}
