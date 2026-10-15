<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link } from '@inertiajs/svelte'
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

<div bind:this={root} class="mx-auto max-w-xl">
  <div class="paper shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)]">
    <div class="flex items-center justify-between border-b border-ink/10 p-3 md:p-6">
      <h1 class="font-display text-lg text-ink md:text-2xl">
        {project ? 'Edit Project' : 'Create New Project'}
      </h1>
      <Link
        href={back}
        component={project ? pages.project : pages.projects}
        pageProps={project ? (_, shared) => ({ ...shared, project }) : null}
        aria-label="Close"
        class="flex h-8 w-8 items-center justify-center rounded-full text-2xl leading-none text-ink-soft hover:bg-ink/5 hover:text-ink"
        >×</Link
      >
    </div>

    <form onsubmit={submit} novalidate class="p-3 md:p-6">
      <ProjectFields {form} directUploadUrl={direct_upload_url} />

      {#if !project}
        <p class="mt-4 border-t border-ink/10 pt-3 font-outfit text-xs text-ink-soft md:text-sm">
          Only the title is required. Everything else can be added later. Creating it posts a thread for it in
          the journals channel, as you.
        </p>
      {/if}

      <div class="mt-3 flex justify-end gap-2 md:mt-4 md:gap-3">
        <Link
          href={back}
          component={project ? pages.project : pages.projects}
          pageProps={project ? (_, shared) => ({ ...shared, project }) : null}
          class="btn-paper px-5 py-2">Cancel</Link
        >
        <button
          type="submit"
          class="btn-ink px-5 py-2"
          disabled={form.processing || form.title.trim() === ''}
        >
          {form.processing ? 'Saving...' : project ? 'Save' : 'Create Project'}
        </button>
      </div>
    </form>
  </div>
</div>
