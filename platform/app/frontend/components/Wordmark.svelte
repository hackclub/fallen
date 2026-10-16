<script lang="ts">
  import wordmark from '@/assets/fallen.svg'

  let {
    class: className = 'h-6',
    onDark = false,
    fill,
  }: { class?: string; onDark?: boolean; fill?: string } = $props()
</script>

{#if fill}
  <span role="img" aria-label="Fallen" class="block {className}">
    <span
      class="block aspect-1066/465 w-full mask-contain mask-center mask-no-repeat {fill}"
      style:mask-image="url({wordmark})"
    ></span>
  </span>
{:else}
  <!-- The source is white on transparent; brightness-0 turns it black for light mode unless it sits on a dark background. -->
  <img
    src={wordmark}
    alt="Fallen"
    class="w-auto {onDark ? '' : 'brightness-0 dark:brightness-100'} {className}"
  />
{/if}
