<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import JournalComposer from '@/components/JournalComposer.svelte'
  import JournalItem from '@/components/JournalItem.svelte'
  import type { LapseStatus } from '@/components/LapsePicker.svelte'
  import Pagination from '@/components/Pagination.svelte'
  import ProjectBanner from '@/components/ProjectBanner.svelte'
  import SlackConnect, { type SlackStatus } from '@/components/SlackConnect.svelte'
  import { editProject, projects, project as projectRoute } from '@/routes'
  import { formatMinutes } from '@/lib/format'
  import { pages } from '@/lib/pages'
  import type { Journal, Pagy, Project } from '@/types'

  let {
    project,
    journals,
    pagy,
    slack,
    direct_upload_url,
    owner,
    lapse,
    can,
  }: {
    project: Project
    // Missing for a moment after an instant visit from a project card, which brings only `project`.
    journals?: Journal[]
    pagy?: Pagy
    slack?: SlackStatus
    direct_upload_url?: string
    owner?: { name: string; avatar: string }
    // Deferred, and null on someone else's project.
    lapse?: LapseStatus | null
    can?: { update: boolean; destroy: boolean; journal: boolean }
  } = $props()

  let composer: { open: boolean; journal: Journal | null } = $state({ open: false, journal: null })

  function write(journal: Journal | null = null) {
    composer = { open: true, journal }
  }

  // Home's "Log a journal" links here with #write: open the composer once the page can take a journal.
  let wantsComposer = $state(typeof location !== 'undefined' && location.hash === '#write')
  $effect(() => {
    if (!wantsComposer || !can || !direct_upload_url) return
    wantsComposer = false
    history.replaceState(history.state, '', location.pathname + location.search)
    if (can.journal) write()
  })

  function remove() {
    if (!confirm(`Delete ${project.title} and its journals? The Slack thread stays.`)) return
    router.delete(projects.destroy(project.id).url)
  }

  const links = $derived(
    [
      project.demo_url && { label: 'Demo', href: project.demo_url },
      project.repo_url && { label: 'Repository', href: project.repo_url },
      project.slack_url && { label: 'Slack thread', href: project.slack_url },
    ].filter((link): link is { label: string; href: string } => Boolean(link)),
  )
</script>

<svelte:head><title>{project.title} · Fallen</title></svelte:head>

<div class="mx-auto max-w-3xl">
  <Link
    href={projects.index()}
    component={pages.projects}
    class="font-outfit text-sm text-sky-ice/60 hover:text-white">← Projects</Link
  >

  <div class="paper mt-4 mb-4 overflow-hidden shadow-[0_20px_60px_-20px_rgba(0,0,0,0.7)] md:mb-8">
    <ProjectBanner {project} editable={can?.update ?? false} directUploadUrl={direct_upload_url} />

    <div class="p-4 md:p-6">
      <div class="mb-4 flex flex-col space-y-3 md:flex-row md:items-center md:space-y-0">
        <h1 class="font-display text-2xl md:flex-grow md:text-3xl">{project.title}</h1>
        <div class="flex items-center gap-2 md:ml-4">
          {#if can?.update}
            <Link
              href={editProject(project.id)}
              component={pages.projectForm}
              pageProps={(_, shared) => ({ ...shared, project })}
              class="btn-paper px-4 py-1.5">Edit</Link
            >
          {/if}
          {#if can?.destroy}
            <button type="button" class="btn-paper px-4 py-1.5 hover:text-red-700" onclick={remove}
              >Delete</button
            >
          {/if}
        </div>
      </div>

      <p class="mb-1 flex flex-wrap gap-x-5 gap-y-1 font-outfit text-sm text-ink-soft md:text-base">
        <span>{project.journal_count} {project.journal_count === 1 ? 'journal' : 'journals'}</span>
        <span>{formatMinutes(project.total_minutes)} logged</span>
      </p>

      {#if project.description}
        <p class="mt-4 font-outfit whitespace-pre-wrap text-ink">{project.description}</p>
      {/if}

      {#if links.length > 0}
        <div class="mt-6 flex flex-col gap-3 md:flex-row">
          {#each links as link (link.label)}
            <a href={link.href} target="_blank" rel="noopener" class="btn-paper flex-1 py-2">{link.label} ↗</a
            >
          {/each}
        </div>
      {/if}
    </div>
  </div>

  <div class="space-y-4">
    {#if !journals || !pagy || !slack || !can || !owner}
      <div class="paper px-6 py-5" aria-busy="true">
        <div class="skeleton-ink h-6 w-40"></div>
        <div class="mt-2 skeleton-ink h-4 w-72 max-w-full"></div>
      </div>
      <ul class="space-y-3" aria-busy="true">
        {#each { length: 2 }, i (i)}
          <li class="paper px-6 py-5">
            <div class="skeleton-ink h-4 w-32"></div>
            <div class="mt-3 skeleton-ink h-4 w-full"></div>
            <div class="mt-2 skeleton-ink h-4 w-3/4"></div>
          </li>
        {/each}
      </ul>
    {:else}
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
        <h2 class="mt-8 mb-3 font-display text-2xl text-white">Journals</h2>
        <ol class="space-y-4">
          {#each journals as journal (journal.id)}
            <li><JournalItem {journal} author={owner} editable={can.update} onEdit={write} /></li>
          {/each}
        </ol>
        <Pagination
          {pagy}
          noun="journals"
          class="px-1 font-outfit text-sky-ice/60"
          buttonClass="text-sky-ice/70 hover:text-white disabled:opacity-30"
        />
      {/if}
    {/if}
  </div>
</div>

{#if composer.open && direct_upload_url}
  <JournalComposer
    {project}
    journal={composer.journal}
    directUploadUrl={direct_upload_url}
    {lapse}
    onClose={() => (composer = { open: false, journal: null })}
  />
{/if}
