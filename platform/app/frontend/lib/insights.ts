// Shapes of the Insights model's props (app/models/insights.rb). Plain hashes, so typed here rather than generated.

export type InsightsKind = 'requests' | 'jobs'

export type InsightsSummary = {
  count: number
  per_minute: number
  errors?: number
  avg: number | null
  p50: number | null
  p95: number | null
  p99: number | null
  max: number | null
  db: number | null
  queue_p95?: number | null
}

export type InsightsPoint = {
  at: string
  count: number
  errors: number
  p50: number | null
  p95: number | null
}

export type InsightsRow = {
  name: string
  count: number
  total: number
  avg: number | null
  p50: number | null
  p95: number | null
  max: number | null
  db: number | null
  errors?: number
  queue_p95?: number | null
  queue?: string
}

export type InsightsSlow = {
  name: string
  started_at: string
  duration: number
  db_runtime: number | null
  status?: number
  http_method?: string
  path?: string
  view_runtime?: number | null
  queue_time?: number | null
  queue?: string
}

// Over this, a response time reads as slow; twice it, as very slow.
export const SLOW_MS = 500

export function latencyTone(ms: number | null | undefined): 'default' | 'warn' | 'bad' {
  if (ms == null) return 'default'
  return ms >= SLOW_MS * 2 ? 'bad' : ms >= SLOW_MS ? 'warn' : 'default'
}

export const toneClass = {
  default: '',
  good: 'text-emerald-600 dark:text-emerald-400',
  warn: 'text-amber-600 dark:text-amber-400',
  bad: 'text-destructive',
}
