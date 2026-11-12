<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import { tick, type Component } from 'svelte'
  import GuideProse from '@/components/GuideProse.svelte'
  import Link from '@/components/Link.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { root, workshopGuides } from '@/routes'
  import '@fontsource-variable/geist'

  // The Tamagotchi workshop guide: one page per file in app/frontend/guides/tamagotchi, named by the file, ordered and
  // grouped by its frontmatter. The layout follows the Hack Club Codex: pages on the left, the page's headings on
  // the right.
  let { page: current }: { page: string } = $props()

  const files = import.meta.glob<{
    default: Component
    metadata: { title: string; order: number; group: string }
  }>('@/guides/tamagotchi/*.mdx', { eager: true })
  const pages = Object.entries(files)
    .map(([path, file]) => ({
      id: path.split('/').at(-1)!.replace('.mdx', ''),
      title: file.metadata.title,
      order: file.metadata.order,
      group: file.metadata.group,
      body: file.default,
    }))
    .sort((a, b) => a.order - b.order)
  const groups = [...new Set(pages.map((p) => p.group))].map((name) => ({
    name,
    pages: pages.filter((p) => p.group === name),
  }))

  const index = $derived(pages.findIndex((p) => p.id === current))
  const doc = $derived(pages[index])
  const previous = $derived(pages[index - 1])
  const next = $derived(pages[index + 1])
  const href = (id: string) => workshopGuides.show({ page: id }).url

  type Heading = { id: string; text: string; level: number }
  let article = $state<HTMLElement>()
  let headings = $state<Heading[]>([])
  let active = $state('')

  const slug = (text: string) =>
    text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')

  // The "On this page" list is read from the rendered headings, which get ids so the list can link to them.
  $effect(() => {
    void current
    let observer: IntersectionObserver | undefined
    let stale = false
    tick().then(() => {
      if (stale || !article) return
      const used = new Set<string>()
      const found = [...article.querySelectorAll<HTMLHeadingElement>('h2, h3')]
      headings = found.map((el) => {
        const base = slug(el.textContent ?? '') || 'section'
        let id = base
        for (let n = 2; used.has(id); n++) id = `${base}-${n}`
        used.add(id)
        el.id = id
        return { id, text: el.textContent ?? '', level: el.tagName === 'H2' ? 2 : 3 }
      })
      active = headings[0]?.id ?? ''
      observer = new IntersectionObserver(
        (entries) => {
          const visible = entries.find((entry) => entry.isIntersecting)
          if (visible) active = visible.target.id
        },
        { rootMargin: '-80px 0px -70% 0px' },
      )
      found.forEach((el) => observer!.observe(el))
    })
    return () => {
      stale = true
      observer?.disconnect()
    }
  })
</script>

<svelte:head><title>{doc.title} · Tamagotchi Workshop · Fallen</title></svelte:head>

<div
  class="min-h-screen bg-sky-night text-white"
  style="font-family: 'Geist Variable', ui-sans-serif, system-ui, sans-serif"
>
  <div class="mx-auto max-w-7xl px-4 pb-16 sm:px-6">
    <header class="flex items-center gap-4 py-4 sm:py-6">
      <Link href={root()} aria-label="Fallen">
        <Wordmark onDark class="h-12 sm:h-14" />
      </Link>
      <span class="hidden border-l border-white/20 pl-4 text-white/80 sm:block">Tamagotchi Workshop</span>
    </header>

    <div class="grid gap-6 lg:grid-cols-[14rem_minmax(0,1fr)] xl:grid-cols-[14rem_minmax(0,1fr)_13rem]">
      <aside class="lg:sticky lg:top-6 lg:self-start">
        <details class="sky-card rounded-md! border-white/15 bg-[#0f184a]! p-0 lg:hidden">
          <summary class="cursor-pointer px-4 py-3 font-medium">Menu: {doc.title}</summary>
          <nav class="border-t border-white/10 px-2 py-2">
            {#each groups as group (group.name)}
              <p class="px-2 pt-3 text-xs font-semibold tracking-wide text-white/50 uppercase">
                {group.name}
              </p>
              {#each group.pages as p (p.id)}
                <Link
                  href={href(p.id)}
                  class="block rounded px-2 py-1.5 {p.id === current
                    ? 'bg-white/10 text-white'
                    : 'text-white/70'}"
                >
                  {p.title}
                </Link>
              {/each}
            {/each}
          </nav>
        </details>

        <nav class="sky-card rounded-md! hidden bg-[#0f184a]! px-2 py-3 lg:block" aria-label="Guide pages">
          {#each groups as group (group.name)}
            <p class="px-2 pt-3 text-xs font-semibold tracking-wide text-white/50 uppercase first:pt-0">
              {group.name}
            </p>
            {#each group.pages as p (p.id)}
              <Link
                href={href(p.id)}
                class="block rounded px-2 py-1.5 hover:bg-white/5 hover:text-white {p.id === current
                  ? 'bg-white/10 font-medium text-white'
                  : 'text-white/70'}"
              >
                {p.title}
              </Link>
            {/each}
          {/each}
        </nav>
      </aside>

      <main class="min-w-0">
        <article
          bind:this={article}
          class="sky-card rounded-md! border-white/15 bg-[#0f184a]! px-5 py-6 sm:px-10 sm:py-8"
        >
          <h1 class="text-3xl font-bold tracking-tight text-white">{doc.title}</h1>
          <GuideProse>
            {#key current}
              <doc.body />
            {/key}
          </GuideProse>
        </article>

        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          {#if previous}
            <Link
              href={href(previous.id)}
              class="sky-card rounded-md! border-white/15 bg-[#0f184a]! block hover:border-white/30"
            >
              <span class="text-xs text-white/50">Previous</span>
              <span class="mt-1 block font-medium text-white">{previous.title}</span>
            </Link>
          {:else}
            <span></span>
          {/if}
          {#if next}
            <Link
              href={href(next.id)}
              class="sky-card rounded-md! border-white/15 bg-[#0f184a]! block text-right hover:border-white/30 sm:col-start-2"
            >
              <span class="text-xs text-white/50">Next</span>
              <span class="mt-1 block font-medium text-white">{next.title}</span>
            </Link>
          {/if}
        </div>
      </main>

      <aside class="hidden xl:sticky xl:top-6 xl:block xl:self-start">
        {#if headings.length > 0}
          <nav aria-label="On this page" class="text-sm">
            <p class="mb-2 font-medium text-white">On this page</p>
            <ul class="space-y-1.5 border-l border-white/15">
              {#each headings as heading (heading.id)}
                <li>
                  <a
                    href="#{heading.id}"
                    class="-ml-px block border-l py-0.5 {heading.level === 3
                      ? 'pl-6'
                      : 'pl-3'} {heading.id === active
                      ? 'border-white text-white'
                      : 'border-transparent text-white/60 hover:text-white'}"
                  >
                    {heading.text}
                  </a>
                </li>
              {/each}
            </ul>
          </nav>
        {/if}
      </aside>
    </div>
  </div>
</div>
