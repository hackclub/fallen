<script lang="ts">
  import type { Person } from '@/types'

  // Overlapping faces for a team, owner first. Past `max` the rest show as a count.
  let {
    people,
    max = 4,
    size = 'size-7',
    class: className = '',
  }: { people: Person[]; max?: number; size?: string; class?: string } = $props()

  const shown = $derived(people.slice(0, max))
  const extra = $derived(people.length - shown.length)
</script>

<span class="inline-flex items-center {className}">
  {#each shown as person, i (person.id)}
    <img
      src={person.avatar}
      alt={person.name}
      title={person.name}
      loading="lazy"
      class="{size} shrink-0 rounded-full bg-sky-night object-cover ring-2 ring-sky-night/80 {i > 0
        ? '-ml-2'
        : ''}"
    />
  {/each}
  {#if extra > 0}
    <span
      class="{size} -ml-2 grid shrink-0 place-items-center rounded-full bg-white/20 font-montserrat text-[11px] font-semibold text-cream ring-2 ring-sky-night/80"
      >+{extra}</span
    >
  {/if}
</span>
