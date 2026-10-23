<script lang="ts">
  import { renderMarkdown } from '@/lib/markdown'

  // `glass` for the dark panels (a journal on its project page); paper otherwise (the composer's preview).
  // `photos` are the signed ids of the journal's own uploads, the only images it may show.
  let {
    source,
    photos,
    glass = false,
    class: className = '',
  }: { source: string; photos: string[]; glass?: boolean; class?: string } = $props()

  const html = $derived(renderMarkdown(source, photos))
</script>

<!-- eslint-disable-next-line svelte/no-at-html-tags -- sanitised in renderMarkdown -->
<div class="{glass ? 'prose-glass' : 'prose-journal'} {className}">{@html html}</div>
