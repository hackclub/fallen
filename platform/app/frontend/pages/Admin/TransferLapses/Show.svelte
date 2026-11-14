<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { router, useForm } from '@inertiajs/svelte'
  import { onDestroy } from 'svelte'
  import Link from '@/components/Link.svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import Search from '@lucide/svelte/icons/search'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'
  import Markdown from '@/components/Markdown.svelte'
  import RecordingReview from '@/components/admin/lapse/RecordingReview.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { adminDark } from '@/lib/adminDark.svelte'
  import { csrfToken } from '@/lib/csrf'
  import { formatDateTime, formatMinutes, formatSeconds, timeAgo } from '@/lib/format'
  import { approvedSeconds, type Note, type Recording } from '@/lib/lapseReview'
  import { adminTransfer, adminTransferLapses } from '@/routes'
  import type { AdminTransferLapse } from '@/types'

  let {
    transfer,
    configured,
    can,
  }: { transfer: AdminTransferLapse; configured: boolean; can: { review: boolean } } = $props()

  const initial = (() => transfer)()
  const form = useForm({
    hackatime_user_id: initial.hackatime_user_id ?? '',
    hackatime_projects: initial.hackatime_projects.join(', '),
  })
  const errors = $derived(form.errors as Record<string, string | undefined>)

  function lookUp(event: SubmitEvent) {
    event.preventDefault()
    form
      .transform((data) => ({ lapse: data }))
      .patch(adminTransferLapses.update(transfer.id).url, { preserveScroll: true })
  }

  // The job fills the recordings in; check back until it has.
  const poll = setInterval(() => {
    if (transfer.fetching) router.reload({ only: ['transfer'] })
  }, 3000)
  onDestroy(() => clearInterval(poll))

  // Notes save as they change, a moment after the last edit.
  let annotations: Record<string, Note> = $state($state.snapshot(initial.lapse_annotations))
  let saving: 'idle' | 'saving' | 'saved' | 'failed' = $state('idle')
  let timer: ReturnType<typeof setTimeout> | undefined
  onDestroy(() => clearTimeout(timer))

  function change(key: string, note: Note) {
    annotations[key] = note
    clearTimeout(timer)
    timer = setTimeout(save, 600)
  }

  async function save() {
    saving = 'saving'
    try {
      const response = await fetch(adminTransferLapses.annotations(transfer.id).url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken(),
        },
        body: JSON.stringify({ annotations: JSON.stringify(annotations) }),
      })
      saving = response.ok ? 'saved' : 'failed'
    } catch {
      saving = 'failed'
    }
  }

  const recordings = $derived(transfer.recordings ?? [])
  const editable = $derived(can.review && transfer.status === 'pending')
  const recorded = $derived(recordings.reduce((sum, recording) => sum + recording.seconds, 0))
  const counts = $derived(
    recordings.reduce((sum, recording) => sum + approvedSeconds(recording, annotations[recording.key]), 0),
  )
  const reviewed = $derived(recordings.filter((recording) => annotations[recording.key]?.reviewed).length)

  // Each recording goes under the first devlog written after it started: the work it shows comes before the post.
  const groups = $derived.by(() => {
    const time = (iso: string | null | undefined) => (iso ? new Date(iso).getTime() : NaN)
    const entries = [...transfer.entries].sort((a, b) => (time(a.at) || 0) - (time(b.at) || 0))
    const grouped = entries.map((entry) => ({ entry, recordings: [] as Recording[] }))
    const after: Recording[] = []
    for (const recording of recordings) {
      const group = grouped.find(({ entry }) => time(recording.started_at) <= time(entry.at))
      ;(group ? group.recordings : after).push(recording)
    }
    return { grouped, after }
  })

  const stats = $derived([
    { label: 'Recorded', value: transfer.recordings ? formatSeconds(recorded) : '—' },
    { label: 'Counts after review', value: transfer.recordings ? formatSeconds(counts) : '—' },
    { label: 'Logged in the other program', value: formatMinutes(transfer.snapshot_minutes) },
    { label: 'Claimed on the form', value: formatMinutes(transfer.claimed_minutes) },
    { label: 'Reviewed', value: `${reviewed} of ${recordings.length}` },
  ])
</script>

<svelte:head><title>Lapse review · {transfer.title} · Fallen Admin</title></svelte:head>

<Link
  href={adminTransfer(transfer.id)}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" />
  {transfer.title}
</Link>

<div class="flex flex-wrap items-center gap-2">
  <h1 class="text-2xl font-semibold tracking-tight">Lapse review</h1>
  {#if saving === 'saving'}<Badge variant="secondary">Saving…</Badge>{/if}
  {#if saving === 'saved'}<Badge variant="secondary">Saved</Badge>{/if}
  {#if saving === 'failed'}<Badge variant="destructive">Couldn't save; edit again to retry</Badge>{/if}
</div>
<p class="mt-1 max-w-2xl text-sm text-muted-foreground">
  The Lapse and Lookout recordings their Hackatime projects logged. Cut what shouldn't count, then use what's
  left to decide the hours on the transfer.
</p>

<Card.Root class="mt-6">
  <Card.Header>
    <Card.Title>Where to look</Card.Title>
    <Card.Description>
      Type their Hackatime user id and the Hackatime projects the other program tracked. Nothing is filled in
      from the other program, so check both on Hackatime's admin pages first{transfer.slack_id
        ? ` (their Slack id is ${transfer.slack_id})`
        : ''}.
    </Card.Description>
  </Card.Header>
  <Card.Content>
    {#if !configured}
      <p class="mb-3 text-sm text-destructive">HACKATIME_ADMIN_API_KEY isn't set, so lookups will fail.</p>
    {/if}
    <form class="grid gap-4 sm:grid-cols-[12rem_1fr_auto] sm:items-end" onsubmit={lookUp}>
      <div class="grid gap-1.5">
        <Label for="hackatime-user">Hackatime user id</Label>
        <Input
          id="hackatime-user"
          inputmode="numeric"
          bind:value={form.hackatime_user_id}
          disabled={!editable}
          placeholder="64372"
        />
      </div>
      <div class="grid gap-1.5">
        <Label for="hackatime-projects">Hackatime projects, comma separated</Label>
        <Input
          id="hackatime-projects"
          bind:value={form.hackatime_projects}
          disabled={!editable}
          placeholder="My Project"
        />
      </div>
      {#if editable}
        <Button type="submit" disabled={form.processing}><Search data-icon="inline-start" /> Look up</Button>
      {/if}
      {#if errors.hackatime_user_id}<p class="text-sm text-destructive sm:col-span-3">
          Hackatime user id {errors.hackatime_user_id}
        </p>{/if}
    </form>
    {#if transfer.fetching}
      <p class="mt-3 text-sm text-muted-foreground">Looking up their recordings…</p>
    {:else if transfer.lapse_fetched_at}
      <p class="mt-3 text-xs text-muted-foreground">Looked up {timeAgo(transfer.lapse_fetched_at)}.</p>
    {/if}
  </Card.Content>
</Card.Root>

{#if transfer.lapse_error}
  <div class="mt-4 flex gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm">
    <TriangleAlert class="size-4 shrink-0 text-destructive" />
    <span>Couldn't look them up: {transfer.lapse_error}</span>
  </div>
{/if}

{#if transfer.recordings}
  <div class="mt-6 grid gap-4 sm:grid-cols-3 lg:grid-cols-5">
    {#each stats as stat (stat.label)}
      <Card.Root>
        <Card.Header class="pb-0">
          <Card.Description>{stat.label}</Card.Description>
          <Card.Title class="text-2xl tabular-nums">{stat.value}</Card.Title>
        </Card.Header>
      </Card.Root>
    {/each}
  </div>

  {#if recordings.length === 0}
    <p class="mt-6 text-sm text-muted-foreground">
      No Lapse or Lookout heartbeats in {transfer.hackatime_projects.join(', ')}.
    </p>
  {/if}

  {#snippet list(items: Recording[])}
    <div class="space-y-4">
      {#each items as recording (recording.key)}
        <RecordingReview
          {recording}
          note={annotations[recording.key]}
          hackatimeUserId={transfer.hackatime_user_id}
          slackId={transfer.slack_id}
          {editable}
          onchange={(note) => change(recording.key, note)}
        />
      {/each}
    </div>
  {/snippet}

  {#if recordings.length}
    <div class="mt-8 space-y-8">
      {#each groups.grouped as { entry, recordings: items } (entry.ref)}
        <section class="grid gap-4 lg:grid-cols-[20rem_1fr]">
          <div class="lg:sticky lg:top-4 lg:self-start">
            <div class="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
              {#if entry.at}<time datetime={entry.at}>{formatDateTime(entry.at)}</time>{/if}
              <Badge variant="secondary">{formatMinutes(entry.minutes) || 'no time'} logged</Badge>
              <Badge variant="outline"
                >{formatSeconds(
                  items.reduce(
                    (sum, recording) => sum + approvedSeconds(recording, annotations[recording.key]),
                    0,
                  ),
                )}
                counts</Badge
              >
            </div>
            <Markdown source={entry.body} photos={[]} glass={adminDark.on} class="mt-2 text-sm" />
            {#if entry.images.length}
              <div class="mt-3 flex flex-wrap gap-2">
                {#each entry.images as image (image)}
                  <a href={image} target="_blank" rel="noreferrer">
                    <img src={image} alt="" loading="lazy" class="h-28 rounded-md border object-cover" />
                  </a>
                {/each}
              </div>
            {/if}
          </div>
          {#if items.length}
            {@render list(items)}
          {:else}
            <p class="text-sm text-muted-foreground">No recordings before this devlog.</p>
          {/if}
        </section>
      {/each}
      {#if groups.after.length}
        <section class="grid gap-4 lg:grid-cols-[20rem_1fr]">
          <p class="text-sm text-muted-foreground">
            {groups.grouped.length ? 'After the last devlog' : 'Recordings'}
          </p>
          {@render list(groups.after)}
        </section>
      {/if}
    </div>
  {/if}
{/if}
