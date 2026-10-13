<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import JournalComposer from '@/components/JournalComposer.svelte'
  import JournalItem from '@/components/JournalItem.svelte'
  import Pagination from '@/components/Pagination.svelte'
  import SlackConnect, { type SlackStatus } from '@/components/SlackConnect.svelte'
  import { editProject, projects, project as projectRoute } from '@/routes'
  import type { Journal, Pagy, Project } from '@/types'

  let {
    project,
    journals,
    pagy,
    slack,
    direct_upload_url,
    can,
  }: {
    project: Project
    journals: Journal[]
    pagy: Pagy
    slack: SlackStatus
    direct_upload_url: string
    can: { update: boolean; destroy: boolean; journal: boolean }
  } = $props()

  let composer: { open: boolean; journal: Journal | null } = $state({ open: false, journal: null })

  function write(journal: Journal | null = null) {
    composer = { open: true, journal }
  }

  function remove() {
    if (!confirm(`Delete ${project.title} and its journals? The Slack thread stays.`)) return
    router.delete(projects.destroy(project.id).url)
  }

  const links = $derived(
    [
      project.repo_url && { label: 'repo', href: project.repo_url },
      project.demo_url && { label: 'demo', href: project.demo_url },
      project.slack_url && { label: 'Slack thread', href: project.slack_url },
    ].filter((link): link is { label: string; href: string } => Boolean(link)),
  )
</script>

<svelte:head><title>{project.title} · Fallen</title></svelte:head>

<div class="mx-auto max-w-3xl">
  <Link href={projects.index()} class="font-outfit text-sm text-sky-ice/60 hover:text-white">← Projects</Link>

  <header class="mt-4 flex flex-wrap items-end justify-between gap-4">
    <div class="min-w-0">
      <h1 class="font-display text-3xl text-white">{project.title}</h1>
      {#if project.description}
        <p class="mt-2 max-w-2xl font-outfit whitespace-pre-wrap text-sky-ice/75">{project.description}</p>
      {/if}
      <p class="mt-3 flex flex-wrap gap-4 font-outfit text-sm">
        {#each links as link (link.label)}
          <a href={link.href} target="_blank" rel="noopener" class="text-sky-ice/70 hover:text-white"
            >{link.label} ↗</a
          >
        {/each}
        {#if can.update}
          <Link href={editProject(project.id)} class="text-sky-ice/70 hover:text-white">edit</Link>
        {/if}
        {#if can.destroy}
          <button type="button" class="text-sky-ice/50 hover:text-red-300" onclick={remove}>delete</button>
        {/if}
      </p>
    </div>
    <div class="text-right font-outfit">
      <p class="text-sm text-sky-ice/55">
        {project.journal_count}
        {project.journal_count === 1 ? 'journal' : 'journals'}
      </p>
    </div>
  </header>

  <div class="mt-8 space-y-4">
    {#if can.journal}
      <button
        type="button"
        onclick={() => write()}
        class="paper flex w-full items-center justify-between px-6 py-4 text-left transition hover:-translate-y-px"
      >
        <span>
          <span class="font-display text-xl text-ink">Log a journal</span>
          <span class="block font-outfit text-sm text-ink-soft"
            >What you did this session, how long it took, photos.</span
          >
        </span>
        <span class="btn-ink px-4 py-2">Write</span>
      </button>
    {:else}
      <SlackConnect {slack} returnTo={projectRoute(project.id).url} />
    {/if}

    {#if journals.length === 0}
      <p class="px-1 font-outfit text-sm text-sky-ice/60">
        No journals yet{#if project.slack_url}. Replies in <a
            href={project.slack_url}
            class="underline hover:text-white"
            target="_blank"
            rel="noopener">the Slack thread</a
          > show up here too{/if}.
      </p>
    {:else}
      <ul class="space-y-3">
        {#each journals as journal (journal.id)}
          <JournalItem {journal} onEdit={write} />
        {/each}
      </ul>
      <Pagination
        {pagy}
        noun="journals"
        class="px-1 font-outfit text-sky-ice/60"
        buttonClass="text-sky-ice/70 hover:text-white disabled:opacity-30"
      />
    {/if}

    {#if can.journal}
      <SlackConnect {slack} returnTo={projectRoute(project.id).url} />
    {/if}
  </div>
</div>

{#if composer.open}
  <JournalComposer
    {project}
    journal={composer.journal}
    directUploadUrl={direct_upload_url}
    onClose={() => (composer = { open: false, journal: null })}
  />
{/if}
