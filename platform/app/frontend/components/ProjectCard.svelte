<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { formatMinutes } from '@/lib/format'
  import { pages } from '@/lib/pages'
  import AvatarStack from '@/components/team/AvatarStack.svelte'
  import * as sfx from '@/lib/sfx'
  import { project as projectRoute } from '@/routes'
  import type { Project } from '@/types'
  import defaultBanner from '@/assets/hero/default-banner.jpg'

  // A tile on the glass: the banner (else the newest journal's photo, else the hero art), the title, what has been
  // logged and, on a team project, who is building it. Hover or focus lights the tile's frame.
  let { project }: { project: Project } = $props()
</script>

<Link
  href={projectRoute(project.id)}
  component={pages.project}
  pageProps={(_, shared) => ({ ...shared, project })}
  onclick={sfx.select}
  class="tile flex h-full flex-col"
>
  <div class="relative h-36 overflow-hidden rounded-t-[4px] md:h-44">
    <img src={project.cover_url ?? defaultBanner} alt="" loading="lazy" class="h-full w-full object-cover" />
    <div class="pointer-events-none absolute inset-0 bg-gradient-to-t from-sky-night/50 to-transparent"></div>
  </div>

  <div class="flex flex-grow flex-col px-5 pt-4 pb-5">
    <h2
      class="line-clamp-1 font-montserrat text-xl font-semibold tracking-[-0.02em] text-white drop-shadow-[0_1.5px_4px_rgba(0,0,0,0.35)]"
    >
      {project.title}
    </h2>
    {#if project.description}
      <p class="mt-1 line-clamp-2 font-outfit text-sm break-words text-sky-ice/60">{project.description}</p>
    {:else if project.journal_count === 0}
      <p class="mt-1 font-outfit text-sm text-sky-ice/60">Write a journal after your next session!</p>
    {/if}

    <p class="mt-auto flex flex-wrap items-center gap-2 pt-4">
      <span class="chip">{formatMinutes(project.total_minutes)}</span>
      <span class="chip">{project.journal_count} {project.journal_count === 1 ? 'journal' : 'journals'}</span>
      {#if project.role === 'former'}
        <span class="chip">You left</span>
      {/if}
      {#if project.teammates.length > 1}
        <AvatarStack people={project.teammates} size="size-6" class="ml-auto" />
      {/if}
    </p>
  </div>
</Link>
