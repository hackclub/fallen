<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import ActivityGrid from '@/components/ActivityGrid.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import WriteJournalButton from '@/components/WriteJournalButton.svelte'
  import { formatMinutes } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import type { Project } from '@/types'

  interface Stats {
    minutes: number
    journals: number
    missing_hours: number
    last_journal_at: string | null
  }

  let {
    projects,
    stats,
    activity,
  }: {
    projects?: Project[]
    stats?: Stats
    activity?: { date: string; minutes: number }[]
  } = $props()

  const firstName = $derived(shared().auth.user?.display_name.split(' ')[0] ?? '')
  const today = $derived(activity?.at(-1)?.minutes ?? 0)
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

<PageTitle title="Home" subtitle={firstName ? `Welcome back, ${firstName}!` : undefined} />

{#if !projects || !stats || !activity}
  <div class="space-y-4" aria-busy="true">
    {#each { length: 2 }, i (i)}
      <div class="paper space-y-3 p-4 md:p-6">
        <div class="skeleton-ink h-6 w-48"></div>
        <div class="skeleton-ink h-4 w-full"></div>
        <div class="skeleton-ink h-4 w-2/3"></div>
      </div>
    {/each}
  </div>
{:else}
  <div class="mb-8 paper p-4 md:p-6">
    <h3 class="mb-4 font-display text-xl">Your hours</h3>
    <div class="flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
      <div class="font-outfit">
        <p class="mb-4 text-lg">
          Today you have logged <strong>{formatMinutes(today)}</strong>, and overall you have logged
          <strong>{formatMinutes(stats.minutes)}</strong> across {stats.journals}
          {stats.journals === 1 ? 'journal' : 'journals'}.
        </p>
        <WriteJournalButton {projects} />
      </div>
      <div class="shrink-0">
        <ActivityGrid days={activity} />
        <p class="mt-2 font-outfit text-xs text-ink-soft">Last {activity.length} days</p>
      </div>
    </div>

    {#if stats.missing_hours > 0}
      <div class="mt-4 rounded-xl bg-amber-100/70 p-4 font-outfit">
        <h4 class="mb-1 text-sm font-semibold text-amber-800">
          {stats.missing_hours}
          {stats.missing_hours === 1 ? 'journal is' : 'journals are'} missing hours
        </h4>
        <p class="text-sm text-amber-700">
          Reply to the bot in your Slack thread with how long you worked, or edit the journal on your project
          page.
        </p>
      </div>
    {/if}
  </div>
{/if}

{#if projects?.length}
  <h2 class="mb-4 font-display text-2xl text-white">My Projects</h2>
  <div class="grid auto-rows-fr grid-cols-1 gap-4 md:grid-cols-2 md:gap-8 lg:grid-cols-3">
    {#each projects as project (project.id)}
      <ProjectCard {project} />
    {/each}
  </div>
{/if}
