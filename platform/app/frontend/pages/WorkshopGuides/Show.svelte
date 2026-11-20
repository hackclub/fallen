<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import { tick, type Component } from 'svelte'
  import GuidePager from '@/components/GuidePager.svelte'
  import GuideProse from '@/components/GuideProse.svelte'
  import Link from '@/components/Link.svelte'
  import TamagotchiTabs from '@/components/TamagotchiTabs.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { partUrl, parts } from '@/guides/tamagotchi-parts'
  import { shared } from '@/lib/shared.svelte'
  import { home, root, signIn } from '@/routes'
  import '@fontsource-variable/geist'

  // The Tamagotchi workshop guide, one long page per part (PCB, CAD, Firmware, Submit & finish): one section per file
  // in the part's folder, ordered by its frontmatter. The first section is the part's title; the menu on the left lists
  // every section after it. Previous and Next at the bottom go to the neighbouring parts.
  let { part }: { part: string } = $props()

  type Section = { id: string; title: string; order: number; body: Component }
  type File = { default: Component; metadata: { title: string; order: number } }
  // Each part's files are their own chunks, loaded when the part is opened.
  const files = import.meta.glob<File>(['@/guides/tamagotchi/*.mdx', '@/guides/tamagotchi-*/*.mdx'])

  const index = $derived(parts.findIndex((p) => p.id === part))
  const current = $derived(parts[index])
  const step = (i: number) => parts[i] && { title: `${i + 1}. ${parts[i].title}`, href: partUrl(parts[i].id) }

  type Heading = { id: string; text: string }
  let pages = $state<Section[]>([])
  let article = $state<HTMLElement>()
  let headings = $state<Record<string, Heading[]>>({})
  let section = $state('')
  let active = $state('')
  const sectionTitle = $derived(pages.find((p) => p.id === section)?.title ?? '')

  let menu = $state<HTMLDetailsElement>()

  // Menu links glide to their section instead of jumping (unless the reader asked for less motion), keep the #id in
  // the address bar for sharing, and fold the phone menu away so it doesn't cover the page.
  const go = (event: MouseEvent, id: string) => {
    const target = document.getElementById(id)
    if (!target) return
    event.preventDefault()
    if (menu) menu.open = false
    // On a phone the sticky menu bar sits over the top of the page, so stop below it.
    const clearance = menu?.offsetHeight ? menu.offsetHeight + 24 : 24
    const top = target.getBoundingClientRect().top + window.scrollY - clearance
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches
    window.scrollTo({ top, behavior: still ? 'auto' : 'smooth' })
    history.replaceState(history.state, '', `#${id}`)
  }

  const slug = (text: string) =>
    text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')

  // Load the open part's sections, then set up its headings.
  $effect(() => {
    const folder = current?.folder
    let stale = false
    let teardown: (() => void) | undefined
    const loads = Object.entries(files)
      .filter(([path]) => path.split('/').at(-2) === folder)
      .map(async ([path, load]) => {
        const file = await load()
        return {
          id: path.split('/').at(-1)!.replace('.mdx', ''),
          title: file.metadata.title,
          order: file.metadata.order,
          body: file.default,
        }
      })
    Promise.all(loads).then(async (loaded) => {
      if (stale) return
      pages = loaded.sort((a, b) => a.order - b.order)
      section = pages[0]?.id ?? ''
      headings = {}
      await tick()
      if (!stale) teardown = follow()
    })
    return () => {
      stale = true
      teardown?.()
    }
  })

  // Headings get ids so the list can link to them; section ids are the file names, so old /tamagotchi/<section> links
  // land on their section.
  const follow = () => {
    if (!article) return
    const used = new Set(pages.map((p) => p.id))
    const found = [...article.querySelectorAll<HTMLHeadingElement>('section h2')]
    const bySection: Record<string, Heading[]> = {}
    for (const el of found) {
      const base = slug(el.textContent ?? '') || 'section'
      let id = base
      for (let n = 2; used.has(id); n++) id = `${base}-${n}`
      used.add(id)
      el.id = id
      const owner = el.closest('section')?.id ?? ''
      ;(bySection[owner] ??= []).push({ id, text: el.textContent ?? '' })
    }
    headings = bySection

    // The current section and heading are the last ones whose top has scrolled past the top of the screen.
    const sections = [...article.querySelectorAll('section')]
    const last = (els: HTMLElement[]) => els.findLast((el) => el.getBoundingClientRect().top <= 100)
    const track = () => {
      section = (last(sections) ?? sections[0])?.id ?? section
      const heading = last(found)
      active = heading?.closest('section')?.id === section ? heading.id : ''
    }

    // The screenshots load after the first jump to a #section and push it down, so each one that finishes jumps
    // again, until the reader scrolls on their own.
    const target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)))
    const pending = target ? [...article.querySelectorAll('img')].filter((img) => !img.complete) : []
    const jump = () => {
      if (target) target.scrollIntoView()
      track()
    }
    const stop = () => pending.forEach((img) => img.removeEventListener('load', jump))
    jump()
    pending.forEach((img) => img.addEventListener('load', jump, { once: true }))
    const userScroll = ['wheel', 'touchstart', 'keydown'] as const
    userScroll.forEach((name) => window.addEventListener(name, stop, { once: true, passive: true }))
    window.addEventListener('scroll', track, { passive: true })
    return () => {
      stop()
      userScroll.forEach((name) => window.removeEventListener(name, stop))
      window.removeEventListener('scroll', track)
    }
  }
</script>

{#snippet contents()}
  <ul class="border-l border-dashed border-white/35 text-sm">
    {#each pages.slice(1) as p (p.id)}
      <li>
        <a
          href="#{p.id}"
          onclick={(event) => go(event, p.id)}
          class="-ml-px block border-l py-1 pl-3 font-semibold {p.id === section && !active
            ? 'border-white text-white'
            : p.id === section
              ? 'border-transparent text-white'
              : 'border-transparent text-white/60 hover:text-white'}"
        >
          {p.title}
        </a>
        {#if headings[p.id]?.length}
          <ul class="mb-1">
            {#each headings[p.id] as heading (heading.id)}
              <li>
                <a
                  href="#{heading.id}"
                  onclick={(event) => go(event, heading.id)}
                  class="-ml-px block border-l py-0.5 pl-6 {heading.id === active
                    ? 'border-white text-white'
                    : 'border-transparent text-white/50 hover:text-white'}"
                >
                  {heading.text}
                </a>
              </li>
            {/each}
          </ul>
        {/if}
      </li>
    {/each}
  </ul>
{/snippet}

<svelte:head><title>{current ? `${current.title} · ` : ''}Tamagotchi Workshop · Fallen</title></svelte:head>

<div
  class="min-h-screen bg-sky-night text-white"
  style="font-family: 'Geist Variable', ui-sans-serif, system-ui, sans-serif"
>
  <div class="mx-auto max-w-6xl px-4 pb-16 sm:px-6">
    <!-- Same columns as the page below, so the logo centres over the guide and the pill lines up with its edge. -->
    <div class="grid gap-x-8 lg:grid-cols-[15rem_minmax(0,1fr)]">
      <header
        class="relative flex items-center justify-between py-5 sm:py-8 lg:col-start-2 lg:justify-center"
      >
        <Link href={root()} aria-label="Fallen">
          <Wordmark onDark class="h-12 sm:h-16" />
        </Link>
        {#if shared().auth.user}
          <Link href={home.index()} class="pill-cream max-sm:h-10 max-sm:text-base lg:absolute lg:right-0"
            >Dashboard</Link
          >
        {:else}
          <a href={signIn().url} class="pill-cream max-sm:h-10 max-sm:text-base lg:absolute lg:right-0"
            >Sign in</a
          >
        {/if}
      </header>
    </div>

    <div class="grid gap-8 lg:grid-cols-[15rem_minmax(0,1fr)]">
      <details
        bind:this={menu}
        class="sticky top-2 z-10 rounded-xl border border-white/15 bg-[#0f184a] lg:hidden"
      >
        <summary class="cursor-pointer px-4 py-3 font-medium"
          >{section === pages[0]?.id ? 'Contents' : sectionTitle}</summary
        >
        <nav class="max-h-[70vh] overflow-y-auto border-t border-dashed border-white/35 px-4 py-3">
          {@render contents()}
        </nav>
      </details>

      <aside
        class="hidden lg:sticky lg:top-6 lg:mt-32 lg:block lg:max-h-[calc(100vh-3rem)] lg:self-start lg:overflow-y-auto"
      >
        <nav aria-label="On this page">
          {@render contents()}
        </nav>
      </aside>

      <main class="min-w-0">
        <TamagotchiTabs current={part} />
        <!-- Square top-left corner, so the first tab runs straight down into the panel. -->
        <article
          bind:this={article}
          class="rounded-2xl rounded-tl-none bg-[#0f184a] px-5 py-6 sm:px-10 sm:py-10"
        >
          {#each pages as p, i (p.id)}
            <section
              id={p.id}
              class="scroll-mt-6 {i > 0 ? 'mt-12 border-t border-dashed border-white/35 pt-10' : ''}"
            >
              <h1 class="font-sans text-3xl leading-tight font-extrabold text-white">{p.title}</h1>
              <GuideProse>
                <p.body />
              </GuideProse>
            </section>
          {/each}

          {#if pages.length}
            <GuidePager
              class="mt-12 border-t border-dashed border-white/35 pt-6"
              previous={step(index - 1)}
              next={step(index + 1)}
            />
          {/if}
        </article>
      </main>
    </div>
  </div>
</div>
