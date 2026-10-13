<script lang="ts">
  import { renderMarkdown } from '@/lib/markdown'

  let { source, class: className = '' }: { source: string; class?: string } = $props()

  const html = $derived(renderMarkdown(source))
</script>

<!-- eslint-disable-next-line svelte/no-at-html-tags -- sanitised in renderMarkdown -->
<div class="prose-journal {className}">{@html html}</div>
