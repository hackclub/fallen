<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import CreateProjectModal from '@/components/CreateProjectModal.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import type { SlackStatus } from '@/components/SlackConnect.svelte'
  import { connectSlack, projects } from '@/routes'
  import type { Project } from '@/types'
  import soup from '@/assets/hero/soup-falling.webp'

  let {
    projects: list,
    slack,
    direct_upload_url,
    can,
  }: {
    projects?: Project[]
    slack?: SlackStatus
    direct_upload_url?: string
    can?: { create: boolean }
  } = $props()

  let creating = $state(false)
</script>

<svelte:head><title>My Projects · Fallen</title></svelte:head>

{#snippet createButton(extra = '')}
  {#if can?.create}
    <button
      type="button"
      class="btn-ink px-8 py-2.5 {extra}"
      data-tour="new-project"
      onclick={() => (creating = true)}
    >
      <span class="text-lg leading-none">+</span> Create Project
    </button>
  {:else if slack?.oauth_available}
    <a
      href={connectSlack({ query: { return_to: projects.index().url } }).url}
      class="btn-ink px-8 py-2.5 {extra}"
      data-tour="new-project">Connect Slack</a
    >
  {/if}
{/snippet}

<PageTitle title="My Projects" subtitle="What are you building?" />

{#if !list || !slack}
  <div class="grid auto-rows-fr grid-cols-1 gap-4 md:grid-cols-2 md:gap-8 lg:grid-cols-3" aria-busy="true">
    {#each { length: 3 }, i (i)}
      <div class="paper">
        <div class="h-36 animate-pulse rounded-xl bg-ink/10 md:h-48"></div>
        <div class="space-y-3 p-4 md:p-6">
          <div class="skeleton-ink h-7 w-40"></div>
          <div class="skeleton-ink h-4 w-full"></div>
          <div class="skeleton-ink h-4 w-20"></div>
        </div>
      </div>
    {/each}
  </div>
{:else if list.length === 0}
  <div class="paper flex flex-col items-center p-6 md:p-10">
    <img src={soup} alt="" class="mb-4 h-32 w-32 object-contain sm:mb-6 sm:h-48 sm:w-48" />
    <p class="mb-6 max-w-xl text-center font-outfit text-lg text-ink sm:mb-8 sm:text-xl">
      No projects yet, Create one here!
    </p>
    {@render createButton()}
    {#if !slack.oauth_available && !slack.ready}
      <p class="font-outfit text-xs text-red-700">Slack sign-in is not configured on this server yet.</p>
    {/if}
  </div>
{:else}
  <div class="grid auto-rows-fr grid-cols-1 gap-4 md:grid-cols-2 md:gap-8 lg:grid-cols-3">
    {#each list as project (project.id)}
      <ProjectCard {project} />
    {/each}
    <div
      class="paper flex h-full min-h-48 flex-col items-center justify-center p-6 transition-transform duration-300 hover:scale-[1.02]"
    >
      {@render createButton()}
    </div>
  </div>
{/if}

{#if creating}
  <CreateProjectModal directUploadUrl={direct_upload_url} onClose={() => (creating = false)} />
{/if}
