<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import ActivityGrid from '@/components/ActivityGrid.svelte'
  import GoalCard, { type Goal } from '@/components/GoalCard.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import WriteJournalButton from '@/components/WriteJournalButton.svelte'
  import XpCard, { type Standing } from '@/components/XpCard.svelte'
  import { formatMinutes } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import { stagger } from '@/lib/stagger'
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
    xp,
    goal,
  }: {
    projects?: Project[]
    stats?: Stats
    activity?: { date: string; minutes: number }[]
    xp?: Standing
    goal?: Goal | null
  } = $props()

  const firstName = $derived(shared().auth.user?.display_name.split(' ')[0] ?? '')
  const today = $derived(activity?.at(-1)?.minutes ?? 0)
  const totals = $derived([
    { label: 'Today', value: formatMinutes(today) },
    { label: 'Overall', value: formatMinutes(stats?.minutes ?? 0) },
    { label: stats?.journals === 1 ? 'Journal' : 'Journals', value: String(stats?.journals ?? 0) },
  ])
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

<PageTitle title="Home" subtitle={firstName ? `Welcome back, ${firstName}!` : undefined} />

{#if !projects || !stats || !activity}
  <div class="space-y-6" aria-busy="true">
    {#each { length: 2 }, i (i)}
      <div class="glass space-y-3 px-5 py-5 md:px-6">
        <div class="skeleton h-7 w-48"></div>
        <div class="skeleton h-4 w-full"></div>
        <div class="skeleton h-4 w-2/3"></div>
      </div>
    {/each}
  </div>
{:else}
  <div {@attach stagger} class="stagger-in space-y-6 [--stagger-step:70ms]">
    {#if goal && xp?.team}
      <GoalCard {goal} {today} team={xp.team} rules={xp.rules} />
    {/if}

    {#if xp}
      <XpCard {xp} />
    {/if}

    <section class="glass divide-y divide-white/10" aria-labelledby="hours">
      <h2 id="hours" class="glass-heading">Your hours</h2>
      <div
        class="grid md:grid-cols-[minmax(0,1fr)_auto] md:divide-x md:divide-white/10 max-md:divide-y max-md:divide-white/10"
      >
        <div class="flex flex-col justify-between gap-5 px-5 py-5 md:px-6">
          <dl class="grid grid-cols-3 gap-4">
            {#each totals as stat (stat.label)}
              <div class="flex flex-col-reverse">
                <dt class="mt-1 font-outfit text-sm text-sky-ice/60">{stat.label}</dt>
                <dd class="font-display text-2xl whitespace-nowrap text-white sm:text-3xl md:text-4xl">
                  {stat.value}
                </dd>
              </div>
            {/each}
          </dl>
          <div><WriteJournalButton {projects} /></div>
        </div>
        <div class="px-5 py-5 md:px-6">
          <ActivityGrid days={activity} />
          <p class="mt-2 font-outfit text-xs text-sky-ice/50">Last {activity.length} days</p>
        </div>
      </div>
      {#if stats.missing_hours > 0}
        <SettingRow
          title="{stats.missing_hours} {stats.missing_hours === 1
            ? 'journal is'
            : 'journals are'} missing hours"
          description="Reply to the bot in your Slack thread with how long you worked, or edit the journal on your project page."
        >
          {#snippet lead()}
            <span
              class="size-3 rounded-full bg-saffron shadow-[0_0_10px_var(--color-saffron)]"
              aria-hidden="true"
            ></span>
          {/snippet}
        </SettingRow>
      {/if}
    </section>

    {#if projects.length}
      <section aria-labelledby="my-projects">
        <h2 id="my-projects" class="mb-4 font-display text-3xl text-white">My Projects</h2>
        <div class="grid auto-rows-fr grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3">
          {#each projects as project (project.id)}
            <ProjectCard {project} />
          {/each}
        </div>
      </section>
    {/if}
  </div>
{/if}
