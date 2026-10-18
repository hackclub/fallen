<script lang="ts">
  // A full-width drawing of Lulu and Sami between sections of a doc, named by file in assets/docs (see
  // JournalExample).
  let { image, alt }: { image: string; alt: string } = $props()

  const files = import.meta.glob<string>('@/assets/docs/*.webp', { eager: true, import: 'default' })
  const src = $derived(Object.entries(files).find(([path]) => path.endsWith(`/${image}`))?.[1])
</script>

<img {src} {alt} loading="lazy" class="w-full rounded-[4px]" />
