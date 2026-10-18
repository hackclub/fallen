import { createInertiaApp, router, type ResolvedComponent } from '@inertiajs/svelte'
import DefaultLayout from '@/layouts/DefaultLayout.svelte'
import '@/lib/toasts.svelte'
import '@/entrypoints/application.css'

// Lazy: each page is its own chunk, so the admin tables, the landing shaders and so on only download when
// visited. Vite preloads a page's shared chunks with it.
const pages = import.meta.glob<ResolvedComponent>('../pages/**/*.svelte')

// Loaded on its own so the SDK stays out of the main bundle. The meta tag is only rendered when SENTRY_FRONTEND_DSN is set.
const sentryDsn = document.querySelector<HTMLMetaElement>('meta[name="sentry-dsn"]')?.content
if (sentryDsn) import('@/lib/sentry').then(({ initSentry }) => initSentry(sentryDsn))

// Lets ApplicationController#sync_browser_timezone keep users' timezone current without asking.
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
router.on('before', (event) => {
  event.detail.visit.headers['X-Browser-Timezone'] = timezone
})

// During a rolling deploy the HTML and its chunks can come from different pods, so a chunk 404s. Reload once to
// get a consistent set; the timestamp stops a genuinely missing chunk from looping.
const RELOADED_AT = 'fallen:chunk-reload'
function reloadOnce() {
  if (Date.now() - Number(sessionStorage.getItem(RELOADED_AT)) < 10_000) return false
  sessionStorage.setItem(RELOADED_AT, String(Date.now()))
  window.location.reload()
  return true
}
window.addEventListener('vite:preloadError', (event) => {
  if (reloadOnce()) event.preventDefault()
})
function reloadForMissingChunk(error: unknown): never {
  reloadOnce()
  throw error
}

createInertiaApp({
  resolve: (name) => {
    const page = pages[`../pages/${name}.svelte`]
    if (!page) throw new Error(`Missing Inertia page component: app/frontend/pages/${name}.svelte`)
    return page().catch(reloadForMissingChunk)
  },
  // Pages can override this with `export { default as layout } from '...'` in a <script module> block.
  layout: () => DefaultLayout,
  progress: { color: '#ec3750' },
})
