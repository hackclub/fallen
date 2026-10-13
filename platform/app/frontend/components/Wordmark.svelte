<script lang="ts">
  import wordmark from '@/assets/fallen.svg'

  let { class: className = 'h-6', onDark = false }: { class?: string; onDark?: boolean } = $props()
</script>

<!-- The source is white on transparent; brightness-0 turns it black for light mode unless it sits on a dark background. -->
<img
  src={wordmark}
  alt="Fallen"
  class="w-auto {onDark ? '' : 'brightness-0 dark:brightness-100'} {className}"
/>
