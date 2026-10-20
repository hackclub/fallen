const dateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' })
const dateTimeFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' })

export function formatDate(iso: string | null | undefined): string {
  return iso ? dateFormatter.format(new Date(iso)) : 'never'
}

export function formatDateTime(iso: string | null | undefined): string {
  return iso ? dateTimeFormatter.format(new Date(iso)) : 'never'
}

export function formatMinutes(minutes: number | null | undefined): string {
  if (!minutes) return '0m'
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return [hours > 0 && `${hours}h`, (mins > 0 || hours === 0) && `${mins}m`].filter(Boolean).join(' ')
}

const relativeFormatter = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' })

export function timeAgo(iso: string): string {
  const seconds = Math.round((new Date(iso).getTime() - Date.now()) / 1000)
  const steps: [Intl.RelativeTimeFormatUnit, number][] = [
    ['day', 86400],
    ['hour', 3600],
    ['minute', 60],
  ]
  for (const [unit, size] of steps) {
    if (Math.abs(seconds) >= size) return relativeFormatter.format(Math.round(seconds / size), unit)
  }
  return 'just now'
}

// Milliseconds as the shortest readable duration: 4.2 ms, 840 ms, 1.3 s, 2m 05s. The space before the unit is
// non-breaking, so a number never wraps away from it.
export function formatMs(ms: number | null | undefined): string {
  if (ms == null) return '—'
  if (ms < 10) return `${ms.toFixed(1)} ms`
  if (ms < 1000) return `${Math.round(ms)} ms`
  if (ms < 60_000) return `${(ms / 1000).toFixed(ms < 10_000 ? 2 : 1)} s`
  const minutes = Math.floor(ms / 60_000)
  return `${minutes}m ${String(Math.round((ms % 60_000) / 1000)).padStart(2, '0')}s`
}

// Seconds as a duration: 45s, 3m 20s, 2h 5m, 3d 4h.
export function formatSeconds(seconds: number): string {
  if (seconds < 60) return `${Math.round(seconds)}s`
  const steps: [string, number][] = [
    ['d', 86400],
    ['h', 3600],
    ['m', 60],
    ['s', 1],
  ]
  const parts: string[] = []
  let rest = Math.round(seconds)
  for (const [unit, size] of steps) {
    if (rest >= size && parts.length < 2) {
      parts.push(`${Math.floor(rest / size)}${unit}`)
      rest %= size
    }
  }
  return parts.join(' ')
}

const compactFormatter = new Intl.NumberFormat(undefined, { notation: 'compact', maximumFractionDigits: 1 })
const numberFormatter = new Intl.NumberFormat()

export function formatCount(count: number | null | undefined, { compact = false } = {}): string {
  if (count == null) return '—'
  return compact && count >= 10_000 ? compactFormatter.format(count) : numberFormatter.format(count)
}

// timeAgo, but forwards too: "in 5 minutes".
export function timeFromNow(iso: string): string {
  const seconds = Math.round((new Date(iso).getTime() - Date.now()) / 1000)
  if (Math.abs(seconds) < 45) return seconds >= 0 ? 'in a moment' : 'just now'
  return timeAgo(iso)
}
