<script lang="ts">
  import { Link, page } from '@inertiajs/svelte'
  import { Spring, prefersReducedMotion } from 'svelte/motion'
  import SolarHome from '@/components/icons/SolarHome.svelte'
  import SolarSledgehammer from '@/components/icons/SolarSledgehammer.svelte'
  import { home, projects } from '@/routes'
  import { pages } from '@/lib/pages'

  let { class: className = '' }: { class?: string } = $props()

  // Pixels the label springs toward the content on hover and back against the rail on press.
  const HOVER_NUDGE = 5
  const PRESS_NUDGE = -3

  const items = [
    { label: 'Home', icon: SolarHome, href: home.index(), component: pages.home },
    { label: 'Projects', icon: SolarSledgehammer, href: projects.index(), component: pages.projects },
  ].map((item) => ({ ...item, x: new Spring(0, { stiffness: 0.2, damping: 0.6 }) }))

  const path = $derived(page.url.split('?')[0])
  const current = (url: string) => path === url || path.startsWith(`${url}/`)

  // As in jolts: a click flashes the glow to full brightness for a beat, then the item stays dark until the pointer
  // leaves, so hovering through the navigation doesn't count.
  function flash(el: HTMLElement) {
    el.classList.remove('rail-flash')
    void el.offsetWidth // restart the animation if mid-flash
    el.classList.add('rail-flash')

    let gone = false
    el.addEventListener(
      'pointerleave',
      () => {
        gone = true
        el.classList.remove('rail-hold')
      },
      { once: true },
    )
    setTimeout(() => {
      el.classList.remove('rail-flash')
      if (!gone) el.classList.add('rail-hold')
    }, 270)
  }

  function flashOnClick(list: HTMLElement) {
    const onclick = (event: MouseEvent) => {
      const link = (event.target as Element).closest('a')
      if (link) flash(link)
    }
    list.addEventListener('click', onclick)
    return () => list.removeEventListener('click', onclick)
  }

  // The rail lives in the persistent layout, so the same spring keeps its velocity across an Inertia page switch.
  function nudge(x: Spring<number>) {
    return (li: HTMLElement) => {
      let hovered = false
      let pressed = false
      const settle = () => {
        const target = pressed ? PRESS_NUDGE : hovered ? HOVER_NUDGE : 0
        x.set(target, { instant: prefersReducedMotion.current })
      }
      const handlers: [string, (event: PointerEvent) => void][] = [
        ['pointerenter', (e) => ((hovered = e.pointerType === 'mouse'), settle())],
        ['pointerleave', () => ((hovered = pressed = false), settle())],
        ['pointerdown', () => ((pressed = true), settle())],
        ['pointerup', () => ((pressed = false), settle())],
        ['pointercancel', () => ((pressed = false), settle())],
      ]
      for (const [type, fn] of handlers) li.addEventListener(type, fn as EventListener)
      return () => {
        for (const [type, fn] of handlers) li.removeEventListener(type, fn as EventListener)
      }
    }
  }
</script>

<nav aria-label="Main" class={className}>
  <ul {@attach flashOnClick} class="rail flex overflow-hidden rounded-[4px] bg-white/10 md:flex-col">
    {#each items as item (item.label)}
      <li {@attach nudge(item.x)} class="md:w-full">
        <Link
          href={item.href}
          component={item.component}
          class="rail-item md:w-full"
          data-tour={item.component === pages.projects ? 'projects-tab' : undefined}
          aria-current={current(item.href.url) ? 'page' : undefined}
        >
          <span
            class="relative z-10 flex items-center gap-3 drop-shadow-[0_1.5px_4px_rgba(0,0,0,0.35)]"
            style:transform="translateX({item.x.current}px)"
          >
            <item.icon size={24} />
            {item.label}
          </span>
        </Link>
      </li>
    {/each}
  </ul>
</nav>
