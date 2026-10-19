<script lang="ts">
  import { renderMarkdown } from '@/lib/markdown'

  // `glass` for the dark panels (a journal on its project page); paper otherwise (the composer's preview).
  let {
    source,
    glass = false,
    class: className = '',
  }: { source: string; glass?: boolean; class?: string } = $props()

  const html = $derived(renderMarkdown(source))
</script>

<!-- eslint-disable-next-line svelte/no-at-html-tags -- sanitised in renderMarkdown -->
<div class="{glass ? 'prose-glass' : 'prose-journal'} {className}">{@html html}</div>
