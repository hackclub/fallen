<script lang="ts">
  import wordmark from '@/assets/wordmark.png'

  let { class: className = 'h-6' }: { class?: string } = $props()
</script>

<!-- The source is white on transparent; brightness-0 turns it black for light mode. -->
<img src={wordmark} alt="Fallen" class="w-auto brightness-0 dark:brightness-100 {className}" />
