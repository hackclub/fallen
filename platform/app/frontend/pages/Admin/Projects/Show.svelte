<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import BadgeCheck from '@lucide/svelte/icons/badge-check'
  import ExternalLink from '@lucide/svelte/icons/external-link'
  import NumberPopIn from '@/components/admin/NumberPopIn.svelte'
  import Pagination from '@/components/Pagination.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import { adminProjects } from '@/routes'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import type { AdminJournal, AdminProject, Pagy } from '@/types'

  let {
    project,
    journals,
    pagy,
    missing_hours,
    can,
  }: {
    project: AdminProject
    journals: AdminJournal[]
    pagy: Pagy
    missing_hours: number
    can: { update: boolean }
  } = $props()

  let confirmApproval = $state(false)
  let approving = $state(false)

  // The final evolution needs a finished, working project. Approving it is the staff's call (Project#approved=).
  function setApproved(approved: boolean) {
    approving = true
    router.patch(
      adminProjects.update(project.id).url,
      { project: { approved } },
      { preserveScroll: true, onFinish: () => ((approving = false), (confirmApproval = false)) },
    )
  }

  const links = $derived(
    [
      { label: 'Slack thread', href: project.slack_url },
      { label: 'Repo', href: project.repo_url },
      { label: 'Demo', href: project.demo_url },
    ].filter((link): link is { label: string; href: string } => Boolean(link.href)),
  )
  const stats = $derived([
    { label: 'Hours logged', value: formatMinutes(project.total_minutes) },
    { label: 'Journals', value: project.journal_count },
    { label: 'Missing hours', value: missing_hours },
    { label: 'Started', value: formatDate(project.created_at) },
  ])
</script>

<svelte:head><title>{project.title} · Fallen Admin</title></svelte:head>

<Link
  href={adminProjects.index()}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" /> Projects
</Link>

<div class="flex flex-wrap items-start gap-4">
  <div class="min-w-0 flex-1">
    <div class="flex items-center gap-2">
      <h1 class="text-2xl font-semibold tracking-tight">{project.title}</h1>
      {#if project.discarded_at}<Badge variant="destructive">Deleted</Badge>{/if}
      {#if project.approved_at}<Badge><BadgeCheck data-icon="inline-start" /> Approved</Badge>{/if}
    </div>
    {#if project.description}
      <p class="mt-1 max-w-2xl text-sm whitespace-pre-line text-muted-foreground">{project.description}</p>
    {/if}
    <div class="mt-3"><UserCell user={project.user} /></div>
    {#if project.teammates.length > 1}
      <p class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
        Team:
        {#each project.teammates.slice(1) as person (person.id)}
          <span class="inline-flex items-center gap-1.5 text-foreground"
            ><img
              src={person.avatar}
              alt=""
              class="size-5 rounded-full bg-muted object-cover"
            />{person.name}</span
          >
        {/each}
      </p>
    {/if}
  </div>
  <div class="flex flex-wrap gap-2">
    {#if can.update}
      <AlertDialog.Root bind:open={confirmApproval}>
        <AlertDialog.Trigger>
          {#snippet child({ props })}
            <Button {...props} size="sm" variant={project.approved_at ? 'outline' : 'default'}>
              <BadgeCheck data-icon="inline-start" />
              {project.approved_at ? 'Remove approval' : 'Approve finished project'}
            </Button>
          {/snippet}
        </AlertDialog.Trigger>
        <AlertDialog.Content>
          <AlertDialog.Header>
            <AlertDialog.Title>
              {project.approved_at ? 'Remove approval from' : 'Approve'}
              {project.title}?
            </AlertDialog.Title>
            <AlertDialog.Description>
              {project.approved_at
                ? `The pet of everyone on it drops back from its final form until it is approved again.`
                : `Approving says the project is finished and works. Once each person on it has the XP for it, their pet reaches its final form and they qualify.`}
            </AlertDialog.Description>
          </AlertDialog.Header>
          <AlertDialog.Footer>
            <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
            <AlertDialog.Action onclick={() => setApproved(!project.approved_at)} disabled={approving}>
              {project.approved_at ? 'Remove approval' : 'Approve'}
            </AlertDialog.Action>
          </AlertDialog.Footer>
        </AlertDialog.Content>
      </AlertDialog.Root>
    {/if}
    {#each links as link (link.label)}
      <Button variant="outline" size="sm" href={link.href} target="_blank" rel="noreferrer">
        {link.label}
        <ExternalLink data-icon="inline-end" />
      </Button>
    {/each}
  </div>
</div>

<div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
  {#each stats as stat (stat.label)}
    <Card.Root class="t-card-lift">
      <Card.Header class="pb-0">
        <Card.Description>{stat.label}</Card.Description>
        <Card.Title class="text-3xl tabular-nums"><NumberPopIn value={stat.value} /></Card.Title>
      </Card.Header>
    </Card.Root>
  {/each}
</div>

<h2 class="mt-8 mb-4 text-lg font-semibold tracking-tight">Journals</h2>
{#if journals.length === 0}
  <p class="text-sm text-muted-foreground">No journals yet.</p>
{:else}
  <div class="space-y-3">
    {#each journals as journal (journal.id)}
      <Card.Root size="sm">
        <Card.Header>
          <div class="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            <time datetime={journal.created_at} title={formatDateTime(journal.created_at)}>
              {timeAgo(journal.created_at)}
            </time>
            {#if journal.duration_text}
              <Badge variant="secondary">{journal.duration_text}</Badge>
            {:else}
              <Badge variant="outline" class="text-muted-foreground">no hours</Badge>
            {/if}
            {#if journal.hours_self_claimed}
              <Badge variant="destructive" title="More than was tracked and more than its timelapses recorded"
                >self-claimed</Badge
              >
            {/if}
            {#if journal.tracked_text}
              <span title="Huddle and site timer time before this journal"
                >{journal.tracked_text} tracked</span
              >
            {/if}
            <Badge variant="outline">{journal.source}</Badge>
            {#if journal.slack_url}
              <a
                href={journal.slack_url}
                target="_blank"
                rel="noreferrer"
                class="ml-auto hover:text-foreground"
              >
                View in Slack
              </a>
            {/if}
          </div>
        </Card.Header>
        <Card.Content>
          <p class="text-sm whitespace-pre-wrap">{journal.body}</p>
        </Card.Content>
      </Card.Root>
    {/each}
  </div>
  <Pagination
    {pagy}
    noun="journals"
    class="mt-4 text-muted-foreground"
    buttonClass="rounded-md border px-3 py-1.5 hover:bg-accent disabled:opacity-40"
  />
{/if}
