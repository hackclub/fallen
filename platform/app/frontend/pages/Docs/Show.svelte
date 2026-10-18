<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import type { Component } from 'svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import TabbedPanel from '@/components/TabbedPanel.svelte'

  // One tab per file in app/frontend/docs, named by the file (journals.mdx is /docs#journals) and ordered and titled
  // by its frontmatter.
  const files = import.meta.glob<{ default: Component; metadata: { title: string; order: number } }>(
    '@/docs/*.mdx',
    { eager: true },
  )
  const docs = Object.entries(files)
    .map(([path, file]) => ({
      id: path.split('/').at(-1)!.replace('.mdx', ''),
      label: file.metadata.title,
      order: file.metadata.order,
      body: file.default,
    }))
    .sort((a, b) => a.order - b.order)

  let current = $state(docs[0].id)
</script>

<svelte:head><title>Docs · Fallen</title></svelte:head>

<PageTitle title="Docs" />

<TabbedPanel
  items={docs}
  label="Docs"
  bind:current
  panelClass="prose-docs [--stagger-step:25ms] px-5 pt-5 pb-7 md:px-8"
>
  {#snippet panel(id)}
    {@const doc = docs.find((d) => d.id === id)!}
    <h1 class="font-display text-3xl text-white">{doc.label}</h1>
    <doc.body />
  {/snippet}
</TabbedPanel>
