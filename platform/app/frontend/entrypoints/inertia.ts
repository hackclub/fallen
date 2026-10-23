import { createInertiaApp, router, type ResolvedComponent } from '@inertiajs/svelte'
import DefaultLayout from '@/layouts/DefaultLayout.svelte'
import '@/lib/toasts'
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

// During a rolling deploy the HTML and its chunks can come from different pods, so a chunk 404s until the old pod
// is gone, which takes up to a minute. Reload a few times, waiting longer each time, to get a consistent set; the
// count stops a genuinely missing chunk from looping.
const RELOADS = 'fallen:chunk-reloads'
const RELOAD_WAITS = [0, 3_000, 10_000, 30_000]
function reloadOnce() {
  const [count, since] = (sessionStorage.getItem(RELOADS) ?? '0:0').split(':').map(Number)
  const attempt = Date.now() - since < 120_000 ? count : 0
  if (attempt >= RELOAD_WAITS.length) return false
  sessionStorage.setItem(RELOADS, `${attempt + 1}:${attempt === 0 ? Date.now() : since}`)
  setTimeout(() => window.location.reload(), RELOAD_WAITS[attempt])
  return true
}
window.addEventListener('vite:preloadError', (event) => {
  if (reloadOnce()) event.preventDefault()
})
// While the reload is underway, never settle, so Inertia doesn't render a broken page and Sentry doesn't get a
// rejection for a chunk the reload is about to fix.
const untilReload = () => new Promise<never>(() => {})
function reloadForMissingChunk(error: unknown) {
  if (reloadOnce()) return untilReload()
  throw error
}

createInertiaApp({
  resolve: (name) => {
    const page = pages[`../pages/${name}.svelte`]
    if (!page) throw new Error(`Missing Inertia page component: app/frontend/pages/${name}.svelte`)
    // Vite resolves to undefined when the preloadError listener above has cancelled the error to reload.
    return page()
      .then((component) => component ?? untilReload())
      .catch(reloadForMissingChunk)
  },
  // Pages can override this with `export { default as layout } from '...'` in a <script module> block.
  layout: () => DefaultLayout,
  progress: { color: '#ec3750' },
})
