<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { formatMinutes } from '@/lib/format'
  import { pages } from '@/lib/pages'
  import { project as projectRoute } from '@/routes'
  import type { Project } from '@/types'
  import defaultBanner from '@/assets/hero/default-banner.jpg'

  // summer-of-making's project card. The picture is the banner, else the first journal photo, else the hero art.
  let { project }: { project: Project } = $props()
</script>

<Link
  href={projectRoute(project.id)}
  component={pages.project}
  pageProps={(_, shared) => ({ ...shared, project })}
  class="paper flex h-full flex-col transition-transform duration-300 hover:scale-[1.02]"
>
  <div class="relative h-36 overflow-hidden md:h-48">
    <img
      src={project.cover_url ?? defaultBanner}
      alt={project.title}
      loading="lazy"
      class="h-full w-full rounded-xl object-cover"
    />
  </div>

  <div class="flex flex-grow flex-col p-4 md:p-6">
    <h2 class="mb-2 line-clamp-1 font-display text-xl md:mb-3 md:text-2xl">{project.title}</h2>
    {#if project.description}
      <p class="mb-4 line-clamp-3 font-outfit text-sm break-words text-ink-soft md:mb-6 md:text-base">
        {project.description}
      </p>
    {/if}

    <p class="mt-auto font-outfit text-ink-soft/70">
      {formatMinutes(project.total_minutes)}
      <br />
      {project.journal_count}
      {project.journal_count === 1 ? 'journal' : 'journals'}
    </p>
    {#if project.journal_count === 0}
      <p class="font-outfit text-ink-soft/70">Write a journal after your next session!</p>
    {/if}
  </div>
</Link>
