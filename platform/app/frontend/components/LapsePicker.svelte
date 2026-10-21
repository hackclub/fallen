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
  import { formatDate } from '@/lib/format'
  import { connectLapse, lapseSync } from '@/routes'

  let {
    lapse,
    current = [],
    locked = false,
    selected = $bindable(),
    returnTo,
    error,
  }: {
    lapse?: LapseStatus | null
    // The timelapses already on the journal being edited: selectable here though the list marks them as used.
    current?: LapseTimelapse[]
    // Hours already logged: shows the journal's timelapses, nothing to pick or drop.
    locked?: boolean
    selected: string[]
    returnTo: string
    error?: string
  } = $props()

  const STALE_MS = 60_000
  const POLL_MS = 2_000
  const POLL_TRIES = 8

  let syncing = $state(false)
  let syncFailed = $state(false)

  // Why a timelapse can't be picked here: Lapse's own state, or another journal already has it.
  function blocked(timelapse: LapseTimelapse) {
    if (timelapse.unusable_reason) return timelapse.unusable_reason
    if (timelapse.claim_text && !current.some((c) => c.id === timelapse.id))
      return `is ${timelapse.claim_text}`
    return null
  }

  // The ones that can still be picked first.
  const options = $derived(
    (locked
      ? current
      : [...current, ...(lapse?.timelapses ?? []).filter((t) => !current.some((c) => c.id === t.id))]
    ).sort((a, b) => Number(Boolean(blocked(a))) - Number(Boolean(blocked(b)))),
  )
  // Same decimal hours as Duration.format on the server, which does the real sum.
  const totalMinutes = $derived(
    options.filter((t) => selected.includes(t.id)).reduce((sum, t) => sum + t.duration_minutes, 0),
  )
  const totalText = $derived(`${Math.round((totalMinutes / 60) * 100) / 100}h`)

  // Lapse is only asked when the composer opens or on Refresh; the list itself comes from Fallen's copy.
  function sync() {
    if (locked || !lapse?.connected || syncing) return
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
    if (locked || blocked(timelapse)) return
    selected = selected.includes(timelapse.id)
      ? selected.filter((id) => id !== timelapse.id)
      : [...selected, timelapse.id]
  }
</script>

{#if lapse === undefined && !locked}
  <div aria-busy="true">
    <div class="skeleton-ink h-6 w-28"></div>
    <div class="mt-3 grid grid-cols-2 gap-2.5">
      <div class="skeleton-ink aspect-video"></div>
      <div class="skeleton-ink aspect-video"></div>
    </div>
  </div>
{:else if lapse?.configured || locked}
  <div class="flex flex-1 flex-col lg:min-h-0">
    <div class="flex items-baseline justify-between gap-2">
      <p class="font-display text-xl text-ink">
        Timelapses
        {#if !locked}<span class="font-outfit text-xs text-ink-soft">(optional)</span>{/if}
      </p>
      {#if lapse?.connected && !locked}
        <button
          type="button"
          onclick={sync}
          disabled={syncing}
          class="cursor-pointer font-outfit text-xs text-ink-soft underline hover:text-ink disabled:cursor-default disabled:no-underline"
        >
          {syncing ? 'Checking Lapse…' : 'Refresh'}
        </button>
      {/if}
    </div>

    {#if !lapse?.connected && !locked}
      <div class="mt-2 rounded-xl border-2 border-dashed border-paper-edge p-3 text-center">
        <p class="font-outfit text-xs text-ink-soft">
          Recorded the session on Lapse? Connect it and pick the timelapses that back up your hours.
        </p>
        <a
          href={connectLapse({ query: { return_to: returnTo } }).url}
          class="sketch-button mt-3 py-1.5 text-sm">Connect Lapse</a
        >
      </div>
    {:else}
      <p class="mb-2.5 font-outfit text-xs text-ink-soft">
        {locked
          ? 'These stay with the journal, like its hours.'
          : "Pick every one from this session, so you don't get deflated."}
        {#if syncFailed}<span class="text-red-700">Couldn't reach Lapse just now.</span>{/if}
      </p>
      {#if options.length === 0}
        <p
          class="rounded-xl border-2 border-dashed border-paper-edge px-3 py-4 text-center font-outfit text-xs text-ink-soft"
        >
          {syncing ? 'Looking for your timelapses…' : 'No timelapses yet.'}
          <a href="https://lapse.hackclub.com" target="_blank" rel="noopener" class="underline hover:text-ink"
            >Record one on Lapse ↗</a
          >
        </p>
      {:else}
        <ul
          class="sketch-scroll grid max-h-[18.5rem] grid-cols-2 content-start gap-2 overflow-y-auto p-0.5 lg:max-h-none lg:min-h-0 lg:flex-1"
          aria-label="Timelapses"
        >
          {#each options as timelapse (timelapse.id)}
            {@const active = selected.includes(timelapse.id)}
            {@const reason = blocked(timelapse)}
            <li class="min-w-0">
              <button
                type="button"
                role="checkbox"
                aria-checked={active}
                disabled={locked || Boolean(reason)}
                title={reason ? `This timelapse ${reason}` : undefined}
                onclick={() => toggle(timelapse)}
                class={['lapse-tile', active && 'active', reason && 'blocked']}
              >
                <span class="lapse-thumb">
                  {#if timelapse.thumbnail_url}
                    <img src={timelapse.thumbnail_url} alt="" loading="lazy" />
                  {/if}
                  {#if timelapse.duration_text}<span class="lapse-length">{timelapse.duration_text}</span
                    >{/if}
                  {#if active}
                    <span class="lapse-check" aria-hidden="true">
                      <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2.4">
                        <path d="M2.5 6.5l2.5 2.5 4.5-5.5" stroke-linecap="round" stroke-linejoin="round" />
                      </svg>
                    </span>
                  {/if}
                </span>
                <span class="block truncate px-0.5 pt-1.5 font-outfit text-[13px] font-semibold text-ink"
                  >{timelapse.name || 'Untitled timelapse'}</span
                >
                {#if !reason || !timelapse.claim_url}
                  <span class="block truncate px-0.5 font-outfit text-[11px] text-ink-soft">
                    {reason
                      ? reason.replace(/^is /, '')
                      : timelapse.recorded_at && formatDate(timelapse.recorded_at)}
                  </span>
                {/if}
              </button>
              {#if reason && timelapse.claim_url}
                <!-- Where it went: the journal that has it, in a new tab so this one keeps the draft. -->
                <a
                  href={timelapse.claim_url}
                  target="_blank"
                  rel="noopener"
                  title="This timelapse {reason}"
                  class="block truncate px-1.5 font-outfit text-[11px] text-ink-soft underline hover:text-ink"
                  >Used in a journal ↗</a
                >
              {/if}
            </li>
          {/each}
        </ul>
        <p class="mt-2 font-outfit text-sm text-ink" aria-live="polite">
          {#if selected.length > 0}
            <strong>{totalText}</strong> from {selected.length}
            {selected.length === 1 ? 'timelapse' : 'timelapses'}
          {:else}
            <span class="text-ink-soft">None picked yet.</span>
          {/if}
        </p>
      {/if}
    {/if}
    {#if error}<p class="mt-1 font-outfit text-xs text-red-700">{error}</p>{/if}
  </div>
{/if}

<style>
  .lapse-tile {
    display: block;
    width: 100%;
    cursor: pointer;
    border-radius: 0.75rem;
    padding: 0.3rem 0.3rem 0.4rem;
    text-align: left;
    transition:
      background-color 0.15s,
      transform 0.15s;
  }
  .lapse-tile:hover:not(:disabled) {
    background: rgba(255, 241, 222, 0.8);
    transform: translateY(-1px);
  }
  .lapse-tile:focus-visible {
    outline: 2px solid var(--sb-ring, currentColor);
    outline-offset: 1px;
  }
  .lapse-thumb {
    position: relative;
    display: block;
    aspect-ratio: 16 / 9;
    overflow: hidden;
    border: 2px solid var(--color-paper-edge);
    border-radius: 0.55rem;
    background: rgba(75, 46, 26, 0.12);
    transition:
      border-color 0.15s,
      box-shadow 0.15s;
  }
  .lapse-thumb img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .active .lapse-thumb {
    border-color: var(--sb-ring-deep, currentColor);
    box-shadow: 0 0 0 2px var(--sb-ring, currentColor);
  }
  .active {
    background: rgba(120, 128, 242, 0.13);
  }
  .lapse-length {
    position: absolute;
    right: 0.25rem;
    bottom: 0.25rem;
    border-radius: 9999px;
    padding: 0 0.4rem;
    background: rgba(40, 24, 12, 0.75);
    color: #fff1de;
    font-family: var(--font-outfit);
    font-size: 10px;
    font-weight: 700;
    line-height: 1.5;
  }
  .lapse-check {
    position: absolute;
    top: 0.25rem;
    left: 0.25rem;
    display: flex;
    width: 1.25rem;
    height: 1.25rem;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--sb-ring-deep, currentColor);
    border-radius: 9999px;
    background: var(--sb-ring, currentColor);
    color: #fff;
  }
  .lapse-check svg {
    width: 0.65rem;
  }
  .lapse-tile:disabled:not(.blocked) {
    cursor: default;
  }
  .blocked {
    cursor: not-allowed;
  }
  .blocked .lapse-thumb {
    filter: grayscale(1);
    opacity: 0.45;
  }
</style>
