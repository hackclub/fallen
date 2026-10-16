<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import ActivityGrid from '@/components/ActivityGrid.svelte'
  import CreateProjectModal from '@/components/CreateProjectModal.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import WriteJournalButton from '@/components/WriteJournalButton.svelte'
  import type { SlackStatus } from '@/components/SlackConnect.svelte'
  import { formatMinutes } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import { connectSlack, home } from '@/routes'
  import type { Project } from '@/types'

  interface Stats {
    minutes: number
    journals: number
    missing_hours: number
    last_journal_at: string | null
  }

  // `slack`, `can` and `direct_upload_url` are missing for a moment after an instant visit; the rest are deferred.
  let {
    slack,
    can,
    direct_upload_url,
    projects,
    stats,
    activity,
  }: {
    slack?: SlackStatus
    can?: { create_project: boolean }
    direct_upload_url?: string
    projects?: Project[]
    stats?: Stats
    activity?: { date: string; minutes: number }[]
  } = $props()

  let creating = $state(false)

  const firstName = $derived(shared().auth.user?.display_name.split(' ')[0] ?? '')
  const current = $derived(projects?.[0])
  const today = $derived(activity?.at(-1)?.minutes ?? 0)
  const setUp = $derived(Boolean(slack?.connected && projects?.length && stats?.journals))
</script>

<svelte:head><title>Home · Fallen</title></svelte:head>

{#snippet status(done: boolean)}
  <div
    class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full {done
      ? 'bg-green-100 text-green-800'
      : 'bg-blue-100 text-blue-800'}"
  >
    {done ? '✓' : '•'}
  </div>
{/snippet}

{#snippet pill(text: string)}
  <span
    class="inline-flex items-center rounded-full bg-green-100 px-3 py-1 font-outfit text-sm text-green-800"
  >
    {text}
  </span>
{/snippet}

<PageTitle title="Home" subtitle={firstName ? `Welcome back, ${firstName}!` : undefined} />

{#if !slack || !projects || !stats || !activity}
  <div class="space-y-4" aria-busy="true">
    {#each { length: 2 }, i (i)}
      <div class="paper space-y-3 p-4 md:p-6">
        <div class="skeleton-ink h-6 w-48"></div>
        <div class="skeleton-ink h-4 w-full"></div>
        <div class="skeleton-ink h-4 w-2/3"></div>
      </div>
    {/each}
  </div>
{:else if !setUp}
  <div class="mb-4">
    <h2 class="mb-4 font-display text-2xl text-white">Set up your account!</h2>
    <p class="mb-4 font-outfit text-xl font-semibold text-sky-ice">
      Three steps and you're building. Everything you do here also shows up in Slack.
    </p>

    <div class="space-y-4">
      <div class="paper p-4 md:p-6">
        <div class="mb-2 flex items-start gap-4">
          {@render status(slack.connected)}
          <div class="inline-flex items-baseline gap-4">
            <h3 class="font-outfit text-lg font-semibold">Connect Slack</h3>
            <p class="font-outfit opacity-60">will take 1 minute</p>
          </div>
        </div>
        <div class="font-outfit md:ml-12">
          <p class="mb-4">
            Your project lives as a thread in the journals channel, and every journal is a reply in it, posted
            as you.
          </p>
          {#if slack.connected}
            {@render pill('Slack is connected!')}
          {:else if slack.oauth_available}
            <a href={connectSlack({ query: { return_to: home.index().url } }).url} class="btn-ink px-5 py-2"
              >Connect Slack</a
            >
          {:else}
            <p class="text-sm text-red-700">Slack sign-in is not configured on this server yet.</p>
          {/if}
        </div>
      </div>

      <div class="paper p-4 md:p-6">
        <div class="mb-2 flex items-start gap-4">
          {@render status(projects.length > 0)}
          <div class="inline-flex items-baseline gap-4">
            <h3 class="font-outfit text-lg font-semibold">Create your project</h3>
            <p class="font-outfit opacity-60">will take 2 minutes</p>
          </div>
        </div>
        <div class="font-outfit md:ml-12">
          <p class="mb-4">
            Give it a title and, if you have one, a photo. You can also post about it in the journals channel
            and the bot will offer to track it.
          </p>
          {#if current}
            {@render pill(`Created ${current.title}!`)}
          {:else if can?.create_project}
            <button
              type="button"
              class="btn-ink px-5 py-2"
              data-tour="new-project"
              onclick={() => (creating = true)}>Create Project</button
            >
          {/if}
        </div>
      </div>

      <div class="paper p-4 md:p-6">
        <div class="mb-2 flex items-start gap-4">
          {@render status(stats.journals > 0)}
          <div class="inline-flex items-baseline gap-4">
            <h3 class="font-outfit text-lg font-semibold">Write your first journal</h3>
            <p class="font-outfit opacity-60">after your next session</p>
          </div>
        </div>
        <div class="font-outfit md:ml-12">
          <p class="mb-4">
            When you've worked on it, write what you did and how long it took. Replies in your Slack thread
            count too.
          </p>
          {#if slack.connected}
            <WriteJournalButton {projects} />
          {/if}
        </div>
      </div>
    </div>
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

{#if setUp && projects}
  <h2 class="mb-4 font-display text-2xl text-white">My Projects</h2>
  <div class="grid auto-rows-fr grid-cols-1 gap-4 md:grid-cols-2 md:gap-8 lg:grid-cols-3">
    {#each projects as project (project.id)}
      <ProjectCard {project} />
    {/each}
  </div>
{/if}

{#if creating}
  <CreateProjectModal directUploadUrl={direct_upload_url} onClose={() => (creating = false)} />
{/if}
