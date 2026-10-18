<script lang="ts">
  import koipad from '@/assets/docs/koipad.webp'
  import mpe32 from '@/assets/docs/mpe32board-midi.webp'
  import moon from '@/assets/docs/to-the-moon-together.webp'

  // The project cards under "Awesome Hack Clubber Examples" in the submission guidelines. They live here rather than
  // in submitting.mdx because an .mdx file gets one import (see index.ts). Renders on a transparent background are
  // shown whole (`contain`) rather than cropped to fill the card like a photo.
  const projects: { name: string; by: string; href?: string; image?: string; contain?: boolean }[] = [
    { name: 'KoiPad', by: '@WA2AB1', href: 'https://github.com/wa2ab1/KoiPad', image: koipad },
    {
      name: 'MPE32Board-Midi',
      by: '@danny',
      href: 'https://github.com/udu3324/mpe32board-midi',
      image: mpe32,
      contain: true,
    },
    { name: 'To The Moon Together', by: '@Parker Rupe', image: moon, contain: true },
  ]
</script>

<div class="grid gap-3 sm:grid-cols-3">
  {#each projects as project (project.name)}
    <div class="overflow-hidden rounded-[4px] bg-white/10">
      {#if project.image}
        <img
          src={project.image}
          alt={project.name}
          loading="lazy"
          class={['aspect-[4/3] w-full', project.contain ? 'object-contain p-3' : 'object-cover']}
        />
      {:else}
        <div class="aspect-[4/3] w-full bg-white/5"></div>
      {/if}
      <p class="px-3 py-2.5 text-sm">
        {#if project.href}<a href={project.href} target="_blank" rel="noopener">{project.name}</a
          >{:else}{project.name}{/if}
        <span class="text-pale-blue/70">by {project.by}</span>
      </p>
    </div>
  {/each}
</div>
