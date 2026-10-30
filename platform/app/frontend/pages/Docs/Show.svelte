<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import type { Component, Snippet } from 'svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import TabbedPanel from '@/components/TabbedPanel.svelte'
  import SolarCard from '@/components/icons/SolarCard.svelte'
  import SolarChat from '@/components/icons/SolarChat.svelte'
  import SolarDocument from '@/components/icons/SolarDocument.svelte'
  import SolarQuestion from '@/components/icons/SolarQuestion.svelte'
  import SolarPlane from '@/components/icons/SolarPlane.svelte'
  import SolarNotebook from '@/components/icons/SolarNotebook.svelte'
  import SolarRocket from '@/components/icons/SolarRocket.svelte'
  import { docs as docsRoute } from '@/routes'

  // One tab per file in app/frontend/docs, named by the file (journaling.mdx is /docs/journaling) and ordered, titled and
  // given an icon by its frontmatter.
  const icons: Record<string, Snippet> = {
    start: startIcon,
    note: noteIcon,
    journal: journalIcon,
    submit: submitIcon,
    funding: fundingIcon,
    travel: travelIcon,
    faq: faqIcon,
  }
  const files = import.meta.glob<{
    default: Component
    metadata: { title: string; order: number; icon: string }
  }>('@/docs/*.mdx', { eager: true })
  const docs = Object.entries(files)
    .map(([path, file]) => ({
      id: path.split('/').at(-1)!.replace('.mdx', ''),
      label: file.metadata.title,
      order: file.metadata.order,
      icon: icons[file.metadata.icon],
      body: file.default,
    }))
    .sort((a, b) => a.order - b.order)

  let current = $state(docs[0].id)
</script>

{#snippet startIcon()}<SolarDocument size={24} />{/snippet}
{#snippet noteIcon()}<SolarChat size={24} />{/snippet}
{#snippet journalIcon()}<SolarNotebook size={24} />{/snippet}
{#snippet submitIcon()}<SolarRocket size={24} />{/snippet}
{#snippet fundingIcon()}<SolarCard size={24} />{/snippet}
{#snippet travelIcon()}<SolarPlane size={24} />{/snippet}
{#snippet faqIcon()}<SolarQuestion size={24} />{/snippet}

<svelte:head><title>Docs · Fallen</title></svelte:head>

<PageTitle title="Docs" />

<!-- data-wide gives the docs a wider column than other pages (SkyLayout), for the rail's longer titles. -->
<div data-wide>
  <TabbedPanel
    items={docs}
    label="Docs"
    bind:current
    href={(id) => docsRoute.show({ page: id }).url}
    panelClass="prose-docs [--stagger-step:18ms] px-5 pt-5 pb-7 md:px-8"
  >
    {#snippet panel(id)}
      {@const doc = docs.find((d) => d.id === id)!}
      <h1 class="font-display text-3xl text-white">{doc.label}</h1>
      <doc.body />
    {/snippet}
  </TabbedPanel>
</div>
