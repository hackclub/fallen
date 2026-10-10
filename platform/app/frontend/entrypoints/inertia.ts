import { createInertiaApp, router, type ResolvedComponent } from '@inertiajs/svelte'
import DefaultLayout from '@/layouts/DefaultLayout.svelte'
import '@/entrypoints/application.css'

const pages = import.meta.glob<ResolvedComponent>('../pages/**/*.svelte', { eager: true })

// Lets ApplicationController#sync_browser_timezone keep users' timezone current without asking.
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
router.on('before', (event) => {
  event.detail.visit.headers['X-Browser-Timezone'] = timezone
})

createInertiaApp({
  resolve: (name) => {
    const page = pages[`../pages/${name}.svelte`]
    if (!page) throw new Error(`Missing Inertia page component: app/frontend/pages/${name}.svelte`)
    return page
  },
  // Pages can override this with `export { default as layout } from '...'` in a <script module> block.
  layout: () => DefaultLayout,
  progress: { color: '#ec3750' },
})
