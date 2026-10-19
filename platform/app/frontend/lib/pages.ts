// Inertia component names for instant visits: a Link with `component` renders that page straight away with the
// shared props (plus any `pageProps`), then fills in the rest when the server answers. Pages show skeletons until then.
export const pages = {
  home: 'Home/Index',
  projects: 'Projects/Index',
  project: 'Projects/Show',
  projectForm: 'Projects/Form',
  shop: 'Shop/Show',
  docs: 'Docs/Show',
  settings: 'Settings/Show',
} as const

// An instant visit still waits for the page's lazy chunk, so fetch them once the signed-in shell is idle.
export function warmPages() {
  const load = () => {
    void import('@/pages/Home/Index.svelte')
    void import('@/pages/Projects/Index.svelte')
    void import('@/pages/Projects/Show.svelte')
    void import('@/pages/Projects/Form.svelte')
    void import('@/pages/Shop/Show.svelte')
    void import('@/pages/Docs/Show.svelte')
    void import('@/pages/Settings/Show.svelte')
  }
  if ('requestIdleCallback' in window) requestIdleCallback(load)
  else setTimeout(load, 1000)
}
