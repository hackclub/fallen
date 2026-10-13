<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import ExternalLink from '@lucide/svelte/icons/external-link'
  import NumberPopIn from '@/components/admin/NumberPopIn.svelte'
  import Pagination from '@/components/Pagination.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import { adminProjects } from '@/routes'
  import type { AdminProject, Journal, Pagy } from '@/types'

  let {
    project,
    journals,
    pagy,
    missing_hours,
  }: { project: AdminProject; journals: Journal[]; pagy: Pagy; missing_hours: number } = $props()

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
    </div>
    {#if project.description}
      <p class="mt-1 max-w-2xl text-sm whitespace-pre-line text-muted-foreground">{project.description}</p>
    {/if}
    <div class="mt-3"><UserCell user={project.user} /></div>
  </div>
  <div class="flex flex-wrap gap-2">
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
