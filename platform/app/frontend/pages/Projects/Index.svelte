<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import SlackConnect, { type SlackStatus } from '@/components/SlackConnect.svelte'
  import { timeAgo } from '@/lib/format'
  import { newProject, project as projectRoute, projects } from '@/routes'
  import type { Project } from '@/types'

  let {
    projects: list,
    slack,
    can,
  }: { projects: Project[]; slack: SlackStatus; can: { create: boolean } } = $props()
</script>

<svelte:head><title>Projects · Fallen</title></svelte:head>

<div class="mx-auto max-w-3xl space-y-6">
  <div class="flex items-end justify-between">
    <h1 class="font-display text-3xl text-white">Projects</h1>
    {#if can.create}
      <Link href={newProject()} class="btn-sky-gold px-4 py-2">New project</Link>
    {/if}
  </div>

  {#if !slack.connected}
    <SlackConnect {slack} returnTo={projects.index().url} />
  {/if}

  {#if list.length === 0}
    {#if slack.connected}
      <div class="paper px-6 py-5">
        <p class="font-display text-xl text-ink">No project yet</p>
        <p class="mt-1 max-w-md font-outfit text-sm text-ink-soft">
          One big build for the next fifty days. Start it here, or post about it in the journals channel and
          the bot will offer to track it.
        </p>
        <Link href={newProject()} class="btn-ink mt-4 px-5 py-2.5">Start a project</Link>
      </div>
    {/if}
  {:else}
    <ul class="space-y-3">
      {#each list as project (project.id)}
        <li>
          <Link
            href={projectRoute(project.id)}
            class="paper block px-6 py-5 transition hover:-translate-y-px"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <h2 class="truncate font-display text-xl text-ink">{project.title}</h2>
                {#if project.description}
                  <p class="mt-1 line-clamp-2 font-outfit text-sm text-ink-soft">{project.description}</p>
                {/if}
              </div>
              <div class="shrink-0 text-right font-outfit">
                <p class="text-xs text-ink-soft">
                  {project.journal_count}
                  {project.journal_count === 1 ? 'journal' : 'journals'}
                </p>
              </div>
            </div>
            <p class="mt-3 font-outfit text-xs text-ink-soft">updated {timeAgo(project.updated_at)}</p>
          </Link>
        </li>
      {/each}
    </ul>
  {/if}

  {#if slack.connected}
    <SlackConnect {slack} returnTo={projects.index().url} />
  {/if}
</div>
