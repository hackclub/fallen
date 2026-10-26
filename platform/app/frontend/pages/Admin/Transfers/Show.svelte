<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router, useForm } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import BadgeCheck from '@lucide/svelte/icons/badge-check'
  import ExternalLink from '@lucide/svelte/icons/external-link'
  import RefreshCw from '@lucide/svelte/icons/refresh-cw'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'
  import Markdown from '@/components/Markdown.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { Textarea } from '@/components/admin/ui/textarea'
  import { adminDark } from '@/lib/adminDark.svelte'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import { adminProject, adminTransfers } from '@/routes'
  import type { AdminProjectTransferDetail } from '@/types'

  let {
    transfer,
    xp_per_hour,
    can,
  }: {
    transfer: AdminProjectTransferDetail
    xp_per_hour: number
    can: { approve: boolean; reject: boolean; refetch: boolean }
  } = $props()

  const hoursText = (minutes: number | null) =>
    minutes ? String(Math.round((minutes / 60) * 100) / 100) : ''
  // XpEntry.journal_xp with no streak multiplier: transferred work was done before the streak.
  const xpFor = (hours: string) => {
    const minutes = Math.round(Number(hours) * 60)
    return minutes > 0 ? String(Math.max(Math.round((minutes * xp_per_hour) / 60), 1)) : '0'
  }

  // The form starts from the transfer as it was loaded; a refetch reloads the page with new suggestions.
  const initial = (() => transfer)()
  const form = useForm({
    hours: hoursText(initial.suggested_minutes),
    xp: String(initial.suggested_xp),
    project_id: initial.named_project_id ?? '',
    note: '',
  })
  // The XP follows the hours until it is typed over.
  let xpTouched = $state(false)
  let confirmReject = $state(false)

  function setHours(value: string) {
    form.hours = value
    if (!xpTouched) form.xp = xpFor(value)
  }

  function approve(event: SubmitEvent) {
    event.preventDefault()
    form
      .transform((data) => ({ transfer: data }))
      .post(adminTransfers.approve(transfer.id).url, { preserveScroll: true })
  }

  function reject() {
    router.post(
      adminTransfers.reject(transfer.id),
      { transfer: { note: form.note } },
      { onFinish: () => (confirmReject = false) },
    )
  }

  const errors = $derived(form.errors as Record<string, string | undefined>)
  const snapshot = $derived(transfer.snapshot)
  const decided = $derived(transfer.status !== 'pending')
  const stats = $derived([
    { label: 'Claimed on the form', value: formatMinutes(transfer.claimed_minutes) || '—' },
    {
      label: 'Logged in the other program',
      value: snapshot ? formatMinutes(snapshot.minutes) : transfer.source ? 'Not fetched' : 'Check by hand',
    },
    { label: 'Entries', value: snapshot ? String(snapshot.entry_count) : '—' },
    { label: 'Submitted', value: formatDate(transfer.submitted_at) },
  ])
</script>

<svelte:head><title>{transfer.project_name ?? 'Transfer'} · Fallen Admin</title></svelte:head>

<Link
  href={adminTransfers.index()}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" /> Transfers
</Link>

<div class="flex flex-wrap items-start gap-4">
  <div class="min-w-0 flex-1">
    <div class="flex flex-wrap items-center gap-2">
      <h1 class="text-2xl font-semibold tracking-tight">
        {snapshot?.title ?? transfer.project_name ?? 'Untitled'}
      </h1>
      {#if transfer.status === 'approved'}<Badge><BadgeCheck data-icon="inline-start" /> Approved</Badge>{/if}
      {#if transfer.status === 'rejected'}<Badge variant="destructive">Rejected</Badge>{/if}
      {#if snapshot?.hardware}<Badge variant="secondary">Hardware</Badge>{/if}
    </div>
    {#if snapshot?.title && transfer.project_name && snapshot.title !== transfer.project_name}
      <p class="mt-1 text-sm text-muted-foreground">Called “{transfer.project_name}” on the form.</p>
    {/if}
    <div class="mt-3">
      {#if transfer.user}
        <UserCell user={transfer.user} />
      {:else}
        <p class="text-sm">
          {transfer.name ?? transfer.email} · {transfer.email}
          <Badge variant="destructive" class="ml-1">No Fallen account with this email</Badge>
        </p>
      {/if}
    </div>
  </div>
  <div class="flex flex-wrap gap-2">
    {#if can.refetch}
      <Button
        variant="outline"
        size="sm"
        onclick={() => router.post(adminTransfers.refetch(transfer.id), {}, { preserveScroll: true })}
      >
        <RefreshCw data-icon="inline-start" /> Fetch again
      </Button>
    {/if}
    <Button variant="outline" size="sm" href={transfer.source_url} target="_blank" rel="noreferrer">
      Original project <ExternalLink data-icon="inline-end" />
    </Button>
    {#if snapshot?.repo_url}
      <Button variant="outline" size="sm" href={snapshot.repo_url} target="_blank" rel="noreferrer">
        Repo <ExternalLink data-icon="inline-end" />
      </Button>
    {/if}
    <Button variant="outline" size="sm" href={transfer.airtable_url} target="_blank" rel="noreferrer">
      Form row (screenshots) <ExternalLink data-icon="inline-end" />
    </Button>
  </div>
</div>

<div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
  {#each stats as stat (stat.label)}
    <Card.Root>
      <Card.Header class="pb-0">
        <Card.Description>{stat.label}</Card.Description>
        <Card.Title class="text-2xl tabular-nums">{stat.value}</Card.Title>
      </Card.Header>
    </Card.Root>
  {/each}
</div>

{#if transfer.error}
  <div class="mt-4 flex gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm">
    <TriangleAlert class="size-4 shrink-0 text-destructive" />
    <span>Couldn't read the project: {transfer.error}</span>
  </div>
{/if}
{#if transfer.owner_check === 'differs'}
  <div class="mt-4 flex gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm">
    <TriangleAlert class="size-4 shrink-0 text-destructive" />
    <span>
      The project was written by someone else's Slack account ({snapshot?.owner.name ?? 'unknown'}), not
      {transfer.user?.display_name}'s.
    </span>
  </div>
{:else if transfer.owner_check === 'matches'}
  <p class="mt-4 text-sm text-muted-foreground">
    <BadgeCheck class="inline size-4 align-text-bottom" /> Written by this person's Slack account.
  </p>
{/if}

{#if can.approve}
  <Card.Root class="mt-6">
    <Card.Header>
      <Card.Title>Review</Card.Title>
      <Card.Description>
        Approving copies {snapshot?.entries.length
          ? `the ${snapshot.entries.length} entries in as journals, dated when they were written, with these hours shared out over them`
          : 'one journal with these hours'}, and issues the XP. Journals from a transfer earn no XP of their
        own.
      </Card.Description>
    </Card.Header>
    <Card.Content>
      <form class="grid gap-4 sm:grid-cols-2" onsubmit={approve}>
        <div class="grid gap-1.5">
          <Label for="hours">Hours to count</Label>
          <Input
            id="hours"
            inputmode="decimal"
            value={form.hours}
            oninput={(e) => setHours(e.currentTarget.value)}
            placeholder="12.5"
          />
          {#if errors.approved_minutes}<p class="text-sm text-destructive">
              Hours {errors.approved_minutes}
            </p>{/if}
        </div>
        <div class="grid gap-1.5">
          <Label for="xp">XP to issue</Label>
          <Input id="xp" inputmode="numeric" bind:value={form.xp} oninput={() => (xpTouched = true)} />
          <p class="text-xs text-muted-foreground">{xp_per_hour} XP an hour, with no streak multiplier.</p>
          {#if errors.xp}<p class="text-sm text-destructive">XP {errors.xp}</p>{/if}
        </div>
        <div class="grid gap-1.5 sm:col-span-2">
          <Label for="project">Import into</Label>
          <select
            id="project"
            bind:value={form.project_id}
            class="h-9 rounded-md border border-input bg-transparent px-3 text-sm shadow-xs"
          >
            <option value=""
              >A new project, “{snapshot?.title ?? transfer.project_name ?? 'Transferred project'}”</option
            >
            {#each transfer.user_projects as project (project.id)}
              <option value={project.id}>{project.title}</option>
            {/each}
          </select>
          {#if transfer.fallen_project_url}
            <p class="text-xs text-muted-foreground">
              The form named {transfer.fallen_project_url}{transfer.named_project_id
                ? ''
                : ", which isn't one of this person's projects"}.
            </p>
          {/if}
          {#if errors.project}<p class="text-sm text-destructive">Project {errors.project}</p>{/if}
        </div>
        <div class="grid gap-1.5 sm:col-span-2">
          <Label for="note">Note (optional)</Label>
          <Textarea id="note" bind:value={form.note} rows={2} placeholder="Why these hours, or why not" />
        </div>
        {#if errors.base}<p class="text-sm text-destructive sm:col-span-2">{errors.base}</p>{/if}
        <div class="flex flex-wrap gap-2 sm:col-span-2">
          <Button type="submit" disabled={form.processing || !transfer.user}>
            <BadgeCheck data-icon="inline-start" /> Approve and import
          </Button>
          {#if can.reject}
            <AlertDialog.Root bind:open={confirmReject}>
              <AlertDialog.Trigger>
                {#snippet child({ props })}
                  <Button {...props} type="button" variant="outline">Reject</Button>
                {/snippet}
              </AlertDialog.Trigger>
              <AlertDialog.Content>
                <AlertDialog.Header>
                  <AlertDialog.Title>Reject this transfer?</AlertDialog.Title>
                  <AlertDialog.Description>
                    Nothing is imported. The note above is kept with the decision.
                  </AlertDialog.Description>
                </AlertDialog.Header>
                <AlertDialog.Footer>
                  <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
                  <AlertDialog.Action onclick={reject}>Reject</AlertDialog.Action>
                </AlertDialog.Footer>
              </AlertDialog.Content>
            </AlertDialog.Root>
          {/if}
        </div>
      </form>
    </Card.Content>
  </Card.Root>
{:else if decided}
  <Card.Root class="mt-6">
    <Card.Header>
      <Card.Title>{transfer.status === 'approved' ? 'Approved' : 'Rejected'}</Card.Title>
      <Card.Description>
        By {transfer.reviewer?.display_name ?? 'someone'}
        {#if transfer.decided_at}<span title={formatDateTime(transfer.decided_at)}
            >{timeAgo(transfer.decided_at)}</span
          >{/if}
      </Card.Description>
    </Card.Header>
    <Card.Content class="space-y-1 text-sm">
      {#if transfer.status === 'approved'}
        <p>{formatMinutes(transfer.approved_minutes)} counted, {transfer.xp} XP issued.</p>
        {#if transfer.project}
          <p>
            Imported into <Link href={adminProject(transfer.project.id)} class="underline"
              >{transfer.project.title}</Link
            >.
          </p>
        {/if}
      {/if}
      {#if transfer.note}<p class="whitespace-pre-line text-muted-foreground">{transfer.note}</p>{/if}
    </Card.Content>
  </Card.Root>
{/if}

{#if snapshot}
  <h2 class="mt-8 mb-1 text-lg font-semibold tracking-tight">Overview</h2>
  {#if snapshot.description}
    <p class="mb-4 max-w-2xl text-sm whitespace-pre-line text-muted-foreground">{snapshot.description}</p>
  {/if}
  {#if transfer.fetched_at}
    <p class="mb-4 text-xs text-muted-foreground">Read {timeAgo(transfer.fetched_at)}.</p>
  {/if}
  {#if snapshot.entries.length === 0}
    <p class="text-sm text-muted-foreground">No entries.</p>
  {:else}
    <div class="space-y-3">
      {#each snapshot.entries as entry (entry.ref)}
        <Card.Root size="sm">
          <Card.Header>
            <div class="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
              {#if entry.at}<time datetime={entry.at}>{formatDateTime(entry.at)}</time>{/if}
              <Badge variant="secondary">{formatMinutes(entry.minutes) || 'no time'}</Badge>
            </div>
          </Card.Header>
          <Card.Content>
            <Markdown source={entry.body} photos={[]} glass={adminDark.on} class="text-sm" />
            {#if entry.images.length}
              <div class="mt-3 flex flex-wrap gap-2">
                {#each entry.images as image (image)}
                  <a href={image} target="_blank" rel="noreferrer">
                    <img src={image} alt="" loading="lazy" class="h-28 rounded-md border object-cover" />
                  </a>
                {/each}
              </div>
            {/if}
          </Card.Content>
        </Card.Root>
      {/each}
    </div>
  {/if}
{/if}
