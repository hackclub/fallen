<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import EditProjectModal from '@/components/EditProjectModal.svelte'
  import JournalComposer from '@/components/JournalComposer.svelte'
  import JournalItem from '@/components/JournalItem.svelte'
  import type { LapseStatus } from '@/components/LapsePicker.svelte'
  import Pagination from '@/components/Pagination.svelte'
  import ProjectBanner from '@/components/ProjectBanner.svelte'
  import SlackConnect, { type SlackStatus } from '@/components/SlackConnect.svelte'
  import SolarNotebook from '@/components/icons/SolarNotebook.svelte'
  import InviteModal from '@/components/team/InviteModal.svelte'
  import ProjectTeam from '@/components/team/ProjectTeam.svelte'
  import { projects, project as projectRoute } from '@/routes'
  import { formatMinutes } from '@/lib/format'
  import { pages } from '@/lib/pages'
  import { shared } from '@/lib/shared.svelte'
  import type { TeamStatus } from '@/lib/team'
  import * as sfx from '@/lib/sfx'
  import { stagger } from '@/lib/stagger'
  import type { Journal, Pagy, Person, Project } from '@/types'

  let {
    project,
    journals,
    pagy,
    slack,
    direct_upload_url,
    team,
    people,
    lapse,
    can,
  }: {
    project: Project
    // Missing for a moment after an instant visit from a project card, which brings only `project`.
    journals?: Journal[]
    pagy?: Pagy
    slack?: SlackStatus
    direct_upload_url?: string
    team?: TeamStatus
    // Optional: only sent while the invite popup searches for someone.
    people?: Person[]
    // Deferred, and null on a project the person is not on the team of.
    lapse?: LapseStatus | null
    can?: {
      update: boolean
      destroy: boolean
      journal: boolean
      invite: boolean
      leave: boolean
      remove_teammate: boolean
    }
  } = $props()

  let composer: { open: boolean; journal: Journal | null } = $state({ open: false, journal: null })
  let editing = $state(false)
  let inviting = $state(false)
  const me = $derived(shared().auth.user?.id)

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

<div class="mx-auto max-w-4xl">
  <Link
    href={projects.index()}
    component={pages.projects}
    class="inline-flex items-center gap-1.5 font-montserrat text-sm font-semibold text-sky-ice/60 transition-colors hover:text-white"
    >← Projects</Link
  >

  <section class="glass mt-4 overflow-hidden">
    <ProjectBanner {project} editable={can?.update ?? false} directUploadUrl={direct_upload_url} />

    <div class="pointer-events-none relative -mt-16 px-5 pb-5 md:-mt-20 md:px-6">
      <div class="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
        <h1
          class="min-w-0 font-display text-4xl break-words text-white drop-shadow-[0_2px_10px_rgba(0,0,0,0.5)] md:text-5xl"
        >
          {project.title}
        </h1>
        {#if can?.update || can?.destroy}
          <div class="pointer-events-auto flex items-center gap-2">
            {#if can?.update}
              <button type="button" class="pill-glass h-10 text-sm" onclick={() => (editing = true)}
                >Edit</button
              >
            {/if}
            {#if can?.destroy}
              <button type="button" class="pill-glass h-10 text-sm hover:text-red-300" onclick={remove}
                >Delete</button
              >
            {/if}
          </div>
        {/if}
      </div>

      <p class="mt-3 flex flex-wrap gap-2">
        <span class="chip">{formatMinutes(project.total_minutes)} logged</span>
        <span class="chip"
          >{project.journal_count} {project.journal_count === 1 ? 'journal' : 'journals'}</span
        >
        {#if project.teammates.length > 1}
          <span class="chip">{project.teammates.length} on the team</span>
        {/if}
      </p>

      {#if project.description}
        <p class="pointer-events-auto mt-4 max-w-[42em] font-outfit whitespace-pre-wrap text-pale-blue">
          {project.description}
        </p>
      {/if}
    </div>

    {#if links.length > 0}
      <div class="flex flex-wrap gap-3 border-t border-white/10 px-5 py-4 md:px-6">
        {#each links as link (link.label)}
          <a href={link.href} target="_blank" rel="noopener" class="pill-glass h-10 text-sm">{link.label} ↗</a
          >
        {/each}
      </div>
    {/if}
  </section>

  <div class="mt-6 space-y-5">
    {#if !journals || !pagy || !slack || !can || !team}
      <div class="glass px-5 py-5 md:px-6" aria-busy="true">
        <div class="skeleton h-6 w-40"></div>
        <div class="mt-2 skeleton h-4 w-72 max-w-full"></div>
      </div>
      <ul class="space-y-5" aria-busy="true">
        {#each { length: 2 }, i (i)}
          <li class="glass px-5 py-5 md:px-6">
            <div class="skeleton h-4 w-32"></div>
            <div class="mt-3 skeleton h-4 w-full"></div>
            <div class="mt-2 skeleton h-4 w-3/4"></div>
          </li>
        {/each}
      </ul>
    {:else}
      <ProjectTeam {project} {team} {can} onInvite={() => (inviting = true)} />

      {#if can.journal}
        <button
          type="button"
          onclick={() => {
            sfx.select()
            write()
          }}
          class="glass setting-row w-full cursor-pointer overflow-hidden text-left"
        >
          <span
            class="grid size-12 shrink-0 place-items-center rounded-full bg-cream text-slate-ink shadow-[0_0_14px_rgb(252_249_239/0.35)]"
            aria-hidden="true"><SolarNotebook size={24} /></span
          >
          <span class="min-w-0 flex-1 basis-56">
            <span class="block font-montserrat text-lg font-semibold tracking-[-0.02em] text-white"
              >Log a journal</span
            >
            <span class="mt-0.5 block font-outfit text-sm text-sky-ice/60"
              >What you did this session, how long it took, photos.</span
            >
          </span>
          <span class="pill-cream h-11 text-base max-sm:hidden">Write</span>
        </button>
      {:else if can.invite}
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
        <h2 class="flex items-center gap-3 pt-3 font-display text-3xl text-white">
          Journals <span class="chip">{pagy.count}</span>
        </h2>
        <ol {@attach stagger} class="stagger-in space-y-5 [--stagger-step:70ms]">
          {#each journals as journal (journal.id)}
            <li><JournalItem {journal} editable={journal.author.id === me} onEdit={write} /></li>
          {/each}
        </ol>
        <Pagination
          {pagy}
          noun="journals"
          class="px-1 font-outfit text-sky-ice/60"
          buttonClass="pill-glass h-10 text-sm"
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

{#if inviting && team}
  <InviteModal {project} {team} {people} onClose={() => (inviting = false)} />
{/if}

{#if editing}
  <EditProjectModal {project} directUploadUrl={direct_upload_url} onClose={() => (editing = false)} />
{/if}
