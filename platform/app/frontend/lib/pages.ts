// Inertia component names for instant visits: a Link with `component` renders that page straight away with the
// shared props (plus any `pageProps`), then fills in the rest when the server answers. Pages show skeletons until then.
export const pages = {
  home: 'Home/Index',
  projects: 'Projects/Index',
  project: 'Projects/Show',
  shop: 'Shop/Show',
  docs: 'Docs/Show',
  transfers: 'Transfers/Show',
  settings: 'Settings/Show',
} as const

// An instant visit still waits for the page's lazy chunk, so fetch them once the signed-in shell is idle. Warming is
// best effort: a tab left open across a deploy asks for chunks that are gone, and Safari also fails imports cut off by
// a navigation. Either way the real visit goes through inertia.ts, which reloads for a missing chunk.
export function warmPages() {
  const load = () => {
    for (const page of [
      import('@/pages/Home/Index.svelte'),
      import('@/pages/Projects/Index.svelte'),
      import('@/pages/Projects/Show.svelte'),
      import('@/pages/Shop/Show.svelte'),
      import('@/pages/Docs/Show.svelte'),
      import('@/pages/Transfers/Show.svelte'),
      import('@/pages/Settings/Show.svelte'),
    ])
      page.catch(() => {})
  }
  if ('requestIdleCallback' in window) requestIdleCallback(load)
  else setTimeout(load, 1000)
}
