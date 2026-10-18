import * as Sentry from '@sentry/browser'

// Tracing times page loads, Inertia visits and Web Vitals, and joins the Rails trace through the meta tags in the
// layout and the sentry-trace header on same-origin requests.
export function initSentry(dsn: string) {
  Sentry.init({
    dsn,
    environment: 'production',
    integrations: [Sentry.browserTracingIntegration()],
    tracesSampleRate: 1.0,
  })
}
