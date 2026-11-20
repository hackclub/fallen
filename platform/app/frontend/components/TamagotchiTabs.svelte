<script lang="ts">
  import type { Component } from 'svelte'
  import Link from '@/components/Link.svelte'
  import SolarBox from '@/components/icons/SolarBox.svelte'
  import SolarCpu from '@/components/icons/SolarCpu.svelte'
  import SolarFlag from '@/components/icons/SolarFlag.svelte'
  import SolarProgramming from '@/components/icons/SolarProgramming.svelte'
  import { partUrl, parts } from '@/guides/tamagotchi-parts'

  // The guide's parts as browser tabs on top of the guide panel. The open tab is the panel's colour and flows into it,
  // with the curved feet a browser tab has; the others sit behind it, dimmed.
  let { current }: { current?: string } = $props()

  // A chip for the board, a 3D box for the case, a terminal for the code, a flag for the finish.
  const icons: Record<string, Component<{ class?: string }>> = {
    pcb: SolarCpu,
    cad: SolarBox,
    firmware: SolarProgramming,
    submit: SolarFlag,
  }
</script>

<nav aria-label="Guide pages" class="flex items-end gap-1 overflow-x-auto [scrollbar-width:none]">
  {#each parts as part, i (part.id)}
    {@const Icon = icons[part.id]}
    {@const open = part.id === current}
    <Link
      href={partUrl(part.id)}
      aria-current={open ? 'page' : undefined}
      class="relative flex shrink-0 items-center gap-2 rounded-t-xl px-3 font-montserrat text-sm font-bold tracking-[-0.02em] whitespace-nowrap transition-colors sm:px-5 sm:text-base {open
        ? 'z-10 bg-[#0f184a] py-3 text-white'
        : 'bg-white/5 py-2.5 text-white/60 hover:bg-white/10 hover:text-white'}"
    >
      {#if open}
        <!-- The feet: a quarter circle cut from the panel colour on each side, where the tab meets the panel. -->
        {#if i > 0}
          <span
            aria-hidden="true"
            class="absolute bottom-0 -left-3 size-3 bg-[radial-gradient(circle_at_0_0,transparent_11.5px,#0f184a_12px)]"
          ></span>
        {/if}
        <span
          aria-hidden="true"
          class="absolute -right-3 bottom-0 size-3 bg-[radial-gradient(circle_at_100%_0,transparent_11.5px,#0f184a_12px)]"
        ></span>
      {/if}
      <Icon class="hidden size-5 shrink-0 sm:block" />
      {part.title}
    </Link>
  {/each}
</nav>
