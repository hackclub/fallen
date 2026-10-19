<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import CreateProjectModal from '@/components/CreateProjectModal.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import ProjectCard from '@/components/ProjectCard.svelte'
  import type { SlackStatus } from '@/components/SlackConnect.svelte'
  import { connectSlack, projects } from '@/routes'
  import * as sfx from '@/lib/sfx'
  import { stagger } from '@/lib/stagger'
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
      class="pill-cream {extra}"
      data-tour="new-project"
      onclick={() => {
        sfx.select()
        creating = true
      }}
    >
      <span class="mr-2 text-2xl leading-none">+</span> Create Project
    </button>
  {:else if slack?.oauth_available}
    <a
      href={connectSlack({ query: { return_to: projects.index().url } }).url}
      class="pill-cream {extra}"
      data-tour="new-project">Connect Slack</a
    >
  {/if}
{/snippet}

<PageTitle title="My Projects" subtitle="What are you building?" />

{#if !list || !slack}
  <div class="grid auto-rows-fr grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3" aria-busy="true">
    {#each { length: 3 }, i (i)}
      <div class="glass">
        <div class="h-36 animate-pulse rounded-t-[4px] bg-white/10 md:h-44"></div>
        <div class="space-y-3 px-5 pt-4 pb-5">
          <div class="skeleton h-6 w-40"></div>
          <div class="skeleton h-4 w-full"></div>
          <div class="skeleton h-5 w-28"></div>
        </div>
      </div>
    {/each}
  </div>
{:else if list.length === 0}
  <div class="glass flex flex-col items-center px-6 py-10 md:py-14">
    <img src={soup} alt="" class="mb-4 h-32 w-32 object-contain sm:mb-6 sm:h-44 sm:w-44" />
    <p class="mb-8 font-display text-3xl text-white">No projects yet</p>
    {@render createButton()}
    {#if !slack.oauth_available && !slack.ready}
      <p class="mt-4 font-outfit text-xs text-red-300">Slack sign-in is not configured on this server yet.</p>
    {/if}
  </div>
{:else}
  <div
    {@attach stagger}
    class="stagger-in grid auto-rows-fr grid-cols-1 gap-5 [--stagger-step:60ms] md:grid-cols-2 lg:grid-cols-3"
  >
    {#each list as project (project.id)}
      <ProjectCard {project} />
    {/each}
    <div
      class="flex h-full min-h-48 flex-col items-center justify-center rounded-[4px] border-2 border-dashed border-white/20 p-6"
    >
      {@render createButton('h-11 text-base')}
    </div>
  </div>
{/if}

{#if creating}
  <CreateProjectModal directUploadUrl={direct_upload_url} onClose={() => (creating = false)} />
{/if}
