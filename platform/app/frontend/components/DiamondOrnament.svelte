<script lang="ts">
  // Two overlapping diamond outlines between two dots, in the current colour. Sits on the open FAQ item's border.
  // Its opacity goes on the svg as a whole, so where the outlines cross they don't
  // double up.
  let { class: className = '' }: { class?: string } = $props()
</script>

<svg class={className} width="48" height="32" viewBox="0 0 72 48" fill="none" aria-hidden="true">
  <g stroke="currentColor" stroke-width="2">
    {#each [[8.12132, 24.3345], [23.1213, 23.3345]] as [x, y] (x)}
      <rect
        {x}
        {y}
        width="30"
        height="30"
        transform="rotate(-45 {x} {y})"
        vector-effect="non-scaling-stroke"
      />
    {/each}
  </g>
  <circle cx="67.5" cy="23.5" r="4.5" fill="currentColor" />
  <circle cx="4.5" cy="23.5" r="4.5" fill="currentColor" />
</svg>
