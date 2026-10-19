<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { pages } from '@/lib/pages'
  import { project as projectRoute } from '@/routes'
  import * as sfx from '@/lib/sfx'
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
    onclick={sfx.select}
    class="pill-cream h-11 max-w-full text-base"
    ><span class="truncate">Write a journal for {projects[0].title}</span></Link
  >
{:else if projects.length > 1}
  <details class="relative inline-block" ontoggle={(e) => e.currentTarget.open && sfx.select()}>
    <summary class="pill-cream h-11 cursor-pointer list-none text-base">Write a journal…</summary>
    <ul
      class="absolute left-0 z-20 mt-2 max-h-72 min-w-56 overflow-y-auto rounded-[4px] bg-sky-night/95 py-1 shadow-[0_20px_50px_-15px_rgba(0,0,0,0.8)] ring-1 ring-white/15 backdrop-blur"
    >
      {#each projects as project (project.id)}
        <li>
          <Link
            href={projectRoute(project.id, { anchor: 'write' })}
            component={pages.project}
            pageProps={projectProps(project)}
            class="block truncate px-4 py-2.5 font-montserrat font-semibold text-white hover:bg-white/10 focus-visible:bg-white/10 focus-visible:outline-none"
            >{project.title}</Link
          >
        </li>
      {/each}
    </ul>
  </details>
{/if}
