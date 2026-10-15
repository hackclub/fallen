<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { pages } from '@/lib/pages'
  import { project as projectRoute } from '@/routes'
  import type { Project } from '@/types'

  // Names the project it opens; with several, asks which one instead of picking the last one touched.
  let { projects }: { projects: Project[] } = $props()

  const projectProps = (project: Project) => (_: unknown, shared: Record<string, unknown>) => ({
    ...shared,
    project,
  })
</script>

{#if projects.length === 1}
  <Link
    href={projectRoute(projects[0].id, { anchor: 'write' })}
    component={pages.project}
    pageProps={projectProps(projects[0])}
    class="btn-ink px-5 py-2">Write a journal for {projects[0].title}</Link
  >
{:else if projects.length > 1}
  <details class="relative inline-block">
    <summary class="btn-ink cursor-pointer list-none px-5 py-2">Write a journal…</summary>
    <ul class="absolute left-0 z-20 mt-2 max-h-72 min-w-56 overflow-y-auto paper p-2 font-outfit shadow-lg">
      {#each projects as project (project.id)}
        <li>
          <Link
            href={projectRoute(project.id, { anchor: 'write' })}
            component={pages.project}
            pageProps={projectProps(project)}
            class="block truncate rounded-lg px-3 py-2 hover:bg-black/5">{project.title}</Link
          >
        </li>
      {/each}
    </ul>
  </details>
{/if}
