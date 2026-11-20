<script lang="ts">
  import Link from '@/components/Link.svelte'

  // The Previous and Next cards at the end of each main page of the Tamagotchi guide (PCB, CAD, Firmware, Submit &
  // finish), each half the row and sized like the docs' rail.
  type Step = { title: string; href: string }
  let { previous, next, class: className = '' }: { previous?: Step; next?: Step; class?: string } = $props()
</script>

{#snippet card(step: Step, label: string, forward: boolean)}
  <Link
    href={step.href}
    class="flex min-h-24 flex-1 basis-0 flex-col justify-center gap-1 rounded-lg border border-white/25 bg-white/5 px-6 py-5 transition-colors hover:border-white/70 hover:bg-white/10 {forward
      ? 'items-end text-right'
      : 'items-start text-left'}"
  >
    <span class="text-sm font-medium tracking-wide text-white/60 uppercase">
      {#if !forward}<span aria-hidden="true">←</span>{/if}
      {label}
      {#if forward}<span aria-hidden="true">→</span>{/if}
    </span>
    <span class="font-montserrat text-xl font-semibold tracking-[-0.02em] text-white sm:text-2xl"
      >{step.title}</span
    >
  </Link>
{/snippet}

<nav aria-label="Previous and next page" class="flex flex-col gap-3 sm:flex-row {className}">
  <!-- An empty half keeps a lone card at half width, on its own side. -->
  {#if previous}
    {@render card(previous, 'Previous', false)}
  {:else}
    <span class="hidden flex-1 basis-0 sm:block"></span>
  {/if}
  {#if next}
    {@render card(next, 'Next', true)}
  {:else}
    <span class="hidden flex-1 basis-0 sm:block"></span>
  {/if}
</nav>
