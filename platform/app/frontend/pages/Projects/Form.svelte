<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { Link, useForm } from '@inertiajs/svelte'
  import { project as projectRoute, projects } from '@/routes'
  import type { Project } from '@/types'

  let { project }: { project: Project | null } = $props()

  // svelte-ignore state_referenced_locally
  const form = useForm({
    title: project?.title ?? '',
    description: project?.description ?? '',
    repo_url: project?.repo_url ?? '',
    demo_url: project?.demo_url ?? '',
  })

  function save(event: SubmitEvent) {
    event.preventDefault()
    const target = project ? projects.update(project.id) : projects.create()
    form.transform((data) => ({ project: data })).submit(target)
  }

  const fields = [
    { key: 'repo_url', label: 'Repo', placeholder: 'https://github.com/you/thing' },
    { key: 'demo_url', label: 'Demo or docs', placeholder: 'https://' },
  ] as const
</script>

<svelte:head><title>{project ? `Edit ${project.title}` : 'New project'} · Fallen</title></svelte:head>

<div class="mx-auto max-w-xl">
  <Link
    href={project ? projectRoute(project.id) : projects.index()}
    class="font-outfit text-sm text-sky-ice/60 hover:text-white"
  >
    ← {project ? project.title : 'Projects'}
  </Link>

  <h1 class="mt-4 font-display text-2xl text-white">{project ? 'Edit project' : 'Start a project'}</h1>
  {#if !project}
    <p class="mt-2 font-outfit text-sm text-sky-ice/70">
      One big build. You can change the details later. A thread for it is posted in the Slack journals
      channel.
    </p>
  {/if}

  <form onsubmit={save} class="sky-card mt-6 space-y-5">
    <label class="block">
      <span class="sky-label">What are you building?</span>
      <input
        type="text"
        bind:value={form.title}
        maxlength="120"
        required
        placeholder="A short, memorable name"
        class="input mt-1 border-white/20 bg-sky-night text-white placeholder:text-sky-ice/40"
      />
      {#if form.errors.title}<p class="mt-1 font-outfit text-xs text-red-300">{form.errors.title}</p>{/if}
    </label>

    <label class="block">
      <span class="sky-label">Tell us a bit more</span>
      <textarea
        bind:value={form.description}
        rows="4"
        placeholder="What is it, who is it for, what will it do when it's done?"
        class="input mt-1 border-white/20 bg-sky-night text-white placeholder:text-sky-ice/40"></textarea>
      {#if form.errors.description}<p class="mt-1 font-outfit text-xs text-red-300">
          {form.errors.description}
        </p>{/if}
    </label>

    {#each fields as field (field.key)}
      <label class="block">
        <span class="sky-label">{field.label} <span class="text-sky-ice/35">(optional)</span></span>
        <input
          type="url"
          bind:value={form[field.key]}
          placeholder={field.placeholder}
          class="input mt-1 border-white/20 bg-sky-night text-white placeholder:text-sky-ice/40"
        />
        {#if form.errors[field.key]}<p class="mt-1 font-outfit text-xs text-red-300">
            {form.errors[field.key]}
          </p>{/if}
      </label>
    {/each}

    <div class="flex items-center gap-3">
      <button type="submit" class="btn-sky-gold px-5 py-2" disabled={form.processing}>
        {project ? 'Save' : 'Start project'}
      </button>
      {#if form.recentlySuccessful}<span class="font-outfit text-sm text-sky-ice/70">Saved.</span>{/if}
    </div>
  </form>
</div>
