<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import '@/components/dialog/dialog.css'
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'
  import { project as projectRoute, projects } from '@/routes'
  import { pages } from '@/lib/pages'
  import type { Project } from '@/types'

  // Editing, or creating without the modal (a direct visit to /projects/new).
  let {
    project,
    direct_upload_url,
  }: {
    project: Project | null
    // Missing for a moment after an instant visit; the banner picker waits for it.
    direct_upload_url?: string
  } = $props()

  // svelte-ignore state_referenced_locally
  const form = projectForm(project)
  let root: HTMLElement

  function submit(event: SubmitEvent) {
    event.preventDefault()
    saveProject(form, project, root)
  }

  const back = $derived(project ? projectRoute(project.id) : projects.index())
</script>

<svelte:head><title>{project ? `Edit ${project.title}` : 'Create New Project'} · Fallen</title></svelte:head>

<!-- Dressed like the popups (components/Modal.svelte), since this is the same prompt reached by its own URL. -->
<div bind:this={root} class="mx-auto max-w-xl pt-6">
  <div class="game-card relative">
    <header class="relative -mt-7 mb-2 flex justify-center px-14">
      <h1 class="game-tab max-w-full truncate">{project ? 'Edit Project' : 'Create New Project'}</h1>
    </header>
    <Link
      href={back}
      component={project ? pages.project : pages.projects}
      pageProps={project ? (_, shared) => ({ ...shared, project }) : null}
      aria-label="Close"
      class="game-btn game-btn-white absolute -top-4 -right-3 z-10 size-11 min-h-0 rounded-full p-0 md:-right-4"
    >
      <svg viewBox="0 0 12 12" class="size-3.5" fill="none" stroke="currentColor" stroke-width="2.6">
        <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
      </svg>
    </Link>

    <form onsubmit={submit} novalidate class="px-5 pt-2 pb-6 md:px-9 md:pb-8">
      <ProjectFields {form} directUploadUrl={direct_upload_url} />

      {#if !project}
        <p class="mt-4 text-center font-outfit text-xs text-balance text-ink-soft md:text-sm">
          Only the title is required. Everything else can be added later. Creating it posts a thread for it in
          the journals channel, as you.
        </p>
      {/if}

      <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
        <Link
          href={back}
          component={project ? pages.project : pages.projects}
          pageProps={project ? (_, shared) => ({ ...shared, project }) : null}
          class="game-btn game-btn-white min-w-40">Cancel</Link
        >
        <button
          type="submit"
          class="game-btn game-btn-blue min-w-40"
          disabled={form.processing || form.title.trim() === ''}
        >
          {form.processing ? 'Saving...' : project ? 'Save' : 'Create Project'}
        </button>
      </div>
    </form>
  </div>
</div>
