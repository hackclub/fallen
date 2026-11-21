<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import ActivityGrid from '@/components/ActivityGrid.svelte'
  import DailyGoal, { type Goal } from '@/components/DailyGoal.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import Reveal from '@/components/Reveal.svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import Skeleton from '@/components/Skeleton.svelte'
  import InviteCards from '@/components/team/InviteCards.svelte'
  import LockInReminder, { type Reminder } from '@/components/LockInReminder.svelte'
  import WeeklyEvents, { type Huddle } from '@/components/WeeklyEvents.svelte'
  import WelcomeBackOverlay from '@/components/welcome-back/WelcomeBackOverlay.svelte'
  import XpGoalBar from '@/components/XpGoalBar.svelte'
  import WriteJournalButton from '@/components/WriteJournalButton.svelte'
  import XpCard, { type Standing } from '@/components/XpCard.svelte'
  import { formatMinutes } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import { stagger } from '@/lib/stagger'
  import type { Project, ProjectInvite } from '@/types'

  interface Stats {
    minutes: number
    journals: number
    missing_hours: number
    last_journal_at: string | null
  }

  let {
    projects,
    invites,
    stats,
    activity,
    xp,
    goal,
    reminder,
    huddle,
  }: {
    projects?: Project[]
    invites?: ProjectInvite[]
    stats?: Stats
    activity?: { date: string; minutes: number }[]
    xp?: Standing
    goal?: Goal | null
    reminder?: Reminder
    huddle?: Huddle
  } = $props()

  const firstName = $derived(shared().auth.user?.display_name.split(' ')[0] ?? '')
  const today = $derived(activity?.at(-1)?.minutes ?? 0)
  const showGoal = $derived(!!goal && !!xp?.team)
  // The goal already says what was journaled today.
  const totals = $derived([
    ...(showGoal ? [] : [{ label: 'Today', value: formatMinutes(today) }]),
    { label: 'Overall', value: formatMinutes(stats?.minutes ?? 0) },
    { label: stats?.journals === 1 ? 'Journal' : 'Journals', value: String(stats?.journals ?? 0) },
  ])
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

<PageTitle title="Home" subtitle={firstName ? `Welcome back, ${firstName}!` : undefined} />

<WelcomeBackOverlay reminderOn={reminder?.on ?? false} />

<Reveal loading={!projects || !stats || !activity}>
  {#snippet skeleton()}
    <div class="space-y-6">
      {#each { length: 2 }, i (i)}
        <div class="glass space-y-3 px-5 py-5 md:px-6">
          <Skeleton class="skeleton h-7 w-48" />
          <Skeleton class="skeleton h-4 w-full" />
          <Skeleton class="skeleton h-4 w-2/3" />
        </div>
      {/each}
    </div>
  {/snippet}
  {#if projects && stats && activity}
    <div {@attach stagger} class="stagger-in space-y-6 [--stagger-step:70ms]">
      {#if xp}
        <XpGoalBar
          total={xp.total}
          goal={xp.final_xp}
          lastWeek={xp.last_week}
          deadline={xp.deadline}
          daysLeft={xp.days_left}
        />
      {/if}

      {#if invites?.length}
        <InviteCards {invites} />
      {/if}

      {#if xp}
        <XpCard {xp} />
      {/if}

      <section class="glass">
        <SettingRow
          title="Got thoughts on Fallen? Submit feedback form #2"
          description="Two random people who fill out the form get 15 XP!"
        >
          <a
            href="https://forms.hackclub.com/fallen-feedback"
            target="_blank"
            rel="noopener"
            class="pill-glass">Share feedback ↗</a
          >
        </SettingRow>
      </section>

      <section class="glass divide-y divide-white/10" aria-labelledby="hours">
        <h2 id="hours" class="glass-heading">Your hours</h2>
        {#if goal && xp?.team}
          <DailyGoal {goal} {today} team={xp.team} rules={xp.rules} />
        {/if}
        <div
          class="grid md:grid-cols-[minmax(0,1fr)_auto] md:divide-x md:divide-white/10 max-md:divide-y max-md:divide-white/10"
        >
          <div class="flex flex-col justify-between gap-5 px-5 py-5 md:px-6">
            <dl class={['grid gap-4', showGoal ? 'grid-cols-2' : 'grid-cols-3']}>
              {#each totals as stat (stat.label)}
                <div class="flex flex-col-reverse">
                  <dt class="mt-1 font-outfit text-sm text-sky-ice/60">{stat.label}</dt>
                  <dd class="font-display text-2xl whitespace-nowrap text-white sm:text-3xl md:text-4xl">
                    {stat.value}
                  </dd>
                </div>
              {/each}
            </dl>
            <div>
              <WriteJournalButton projects={projects.filter((project) => project.role !== 'former')} />
            </div>
          </div>
          <div class="px-5 py-5 md:px-6">
            <ActivityGrid days={activity} />
            <p class="mt-2 font-outfit text-xs text-sky-ice/50">Last {activity.length} days</p>
          </div>
        </div>
        {#if reminder}
          <LockInReminder {reminder} />
        {/if}
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

      <WeeklyEvents {huddle} />

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
</Reveal>
