import * as Sentry from '@sentry/browser'

export function initSentry(dsn: string) {
  Sentry.init({ dsn, environment: 'production' })
}
