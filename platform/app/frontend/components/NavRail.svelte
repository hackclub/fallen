<script lang="ts">
  import { Link, page } from '@inertiajs/svelte'
  import SolarHome from '@/components/icons/SolarHome.svelte'
  import SolarDocument from '@/components/icons/SolarDocument.svelte'
  import SolarSettings from '@/components/icons/SolarSettings.svelte'
  import SolarSledgehammer from '@/components/icons/SolarSledgehammer.svelte'
  import { docs, home, projects, settings } from '@/routes'
  import { pages } from '@/lib/pages'
  import { flashOnClick, nudge, nudgeSpring } from '@/lib/rail'

  let { class: className = '' }: { class?: string } = $props()

  const items = [
    { label: 'Home', icon: SolarHome, href: home.index(), component: pages.home },
    { label: 'Projects', icon: SolarSledgehammer, href: projects.index(), component: pages.projects },
    { label: 'Docs', icon: SolarDocument, href: docs.show({}), component: pages.docs },
    { label: 'Settings', icon: SolarSettings, href: settings.show(), component: pages.settings },
  ].map((item) => ({ ...item, x: nudgeSpring() }))

  const path = $derived(page.url.split(/[?#]/)[0])
  const current = (url: string) => path === url || path.startsWith(`${url}/`)
</script>

<nav aria-label="Main" class={className}>
  <ul {@attach flashOnClick} class="rail flex overflow-hidden rounded-[4px] bg-white/10 md:flex-col">
    {#each items as item (item.label)}
      <li {@attach nudge(item.x)} class="md:w-full">
        <!-- prefetch: the page's props are asked for on hover, so the click itself feels instant. -->
        <Link
          href={item.href}
          component={item.component}
          prefetch
          class="rail-item md:w-full"
          data-tour={item.component === pages.projects ? 'projects-tab' : undefined}
          aria-current={current(item.href.url) ? 'page' : undefined}
        >
          <span
            class="relative z-10 flex items-center gap-3 drop-shadow-[0_1.5px_4px_rgba(0,0,0,0.35)]"
            style:transform="translateX({item.x.current}px)"
          >
            <item.icon size={24} />
            <!-- on a phone the row only fits the icons, so only the current page keeps its word -->
            <span class={[!current(item.href.url) && 'max-sm:sr-only']}>{item.label}</span>
          </span>
        </Link>
      </li>
    {/each}
  </ul>
</nav>
