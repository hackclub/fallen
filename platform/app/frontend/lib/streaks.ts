import type { AdminStreak, AdminStreakAdjustment, AdminStreakPreview } from '@/types'

// Helpers for the streak restore screens (/admin/users/:id and /admin/streaks). Dates are the person's own calendar
// days as ISO strings (2026-10-21), read without a timezone so they never shift a day.

export type StreakRow = AdminStreak['rows'][number]
export type StreakDay = StreakRow['days'][number]
export type StreakKind = AdminStreakAdjustment['kind']

// The answer to a restore form's preview (Admin::ApplicationController#streak_preview).
export type StreakPreview = { errors: string[]; plan: AdminStreakPreview | null }

// What a restore form sends, and asks a preview for.
export type StreakFields = {
  kind: StreakKind
  starts_on?: string
  ends_on?: string
  freezes?: number
  multiplier?: number
  xp?: number
  reason: string
  message: string
  notify: boolean
  reprice: boolean
}

const shortDate = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', timeZone: 'UTC' })
const weekday = new Intl.DateTimeFormat(undefined, { weekday: 'short', timeZone: 'UTC' })
const longDay = new Intl.DateTimeFormat(undefined, {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
})

const asDate = (iso: string) => new Date(`${iso}T00:00:00Z`)

export const dayLabel = (iso: string) => shortDate.format(asDate(iso))
export const weekdayLabel = (iso: string) => weekday.format(asDate(iso))
export const longDayLabel = (iso: string) => longDay.format(asDate(iso))
export const dayOfMonth = (iso: string) => asDate(iso).getUTCDate()

export function addDays(iso: string, days: number) {
  const date = asDate(iso)
  date.setUTCDate(date.getUTCDate() + days)
  return date.toISOString().slice(0, 10)
}

export function daysBetween(from: string, to: string) {
  return Math.round((asDate(to).getTime() - asDate(from).getTime()) / 86_400_000)
}

export function rangeLabel(from: string, to: string) {
  return from === to ? dayLabel(from) : `${dayLabel(from)} – ${dayLabel(to)}`
}

export const formatMultiplier = (multiplier: number) => `${multiplier.toFixed(2)}x`

export const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? '' : 's'}`

export function signedXp(xp: number) {
  return `${xp > 0 ? '+' : xp < 0 ? '−' : ''}${Math.abs(xp)} XP`
}

// Days a restore can excuse: ones that didn't count, and ones still to come.
export const EXCUSABLE: StreakDay['state'][] = ['missed', 'frozen', 'today', 'future']

export const DAY_STATES: Record<StreakDay['state'], string> = {
  before: 'Before their first journal',
  journal: 'Journaled',
  excused: 'Excused',
  missed: 'Missed',
  frozen: 'Missed, covered by a freeze',
  today: 'Today, no journal yet',
  future: 'Still to come',
}

export const OUTCOMES: Record<string, string> = {
  kept: 'Kept',
  frozen: 'Kept with freezes',
  broken: 'Broke',
  open: 'In progress',
  paid: 'Bonus paid',
  unpaid: 'No bonus',
  unjudged: 'Not judged',
}

// The short changes an adjustment or incident made, for its log line.
export function effectChips(effect: AdminStreakAdjustment['effect']): string[] {
  const pair = (key: string) => (Array.isArray(effect[key]) ? (effect[key] as number[]) : null)
  const count = (key: string) => (typeof effect[key] === 'number' ? (effect[key] as number) : 0)
  const multiplier = pair('multiplier')
  const freezes = pair('freezes')
  return [
    count('people') > 0 && plural(count('people'), 'person').replace('persons', 'people'),
    multiplier &&
      multiplier[0] !== multiplier[1] &&
      `${formatMultiplier(multiplier[0])} → ${formatMultiplier(multiplier[1])}`,
    freezes && freezes[0] !== freezes[1] && `${freezes[0]} → ${plural(freezes[1], 'freeze')}`,
    count('restored') > 0 && `${plural(count('restored'), 'week')} restored`,
    count('broken') > 0 && `${plural(count('broken'), 'week')} broken again`,
    count('journals') > 0 && `${plural(count('journals'), 'journal')} re-counted`,
    count('bonuses') !== 0 && `${count('bonuses') > 0 ? '+' : ''}${count('bonuses')} Lulu bonus`,
    count('xp') !== 0 && signedXp(count('xp')),
  ].filter((chip): chip is string => Boolean(chip))
}

export function describeAdjustment(adjustment: AdminStreakAdjustment) {
  if (adjustment.kind === 'excuse') return `Excused ${adjustment.days_text}`
  if (adjustment.kind === 'freezes') {
    const count = adjustment.freezes ?? 0
    return `${count >= 0 ? 'Gave' : 'Took back'} ${plural(Math.abs(count), 'freeze')}`
  }
  if (adjustment.kind === 'xp') {
    const xp = adjustment.xp ?? 0
    return `${xp >= 0 ? 'Gave' : 'Took back'} ${Math.abs(xp)} XP`
  }
  return `Set to ${formatMultiplier(adjustment.multiplier ?? 1)} and ${plural(adjustment.freezes ?? 0, 'freeze')}`
}

// Whether the preview changes anything the admin would see.
export function previewChanges(plan: AdminStreakPreview) {
  return (
    plan.multiplier[0] !== plan.multiplier[1] ||
    plan.freezes[0] !== plan.freezes[1] ||
    plan.xp !== 0 ||
    plan.weeks.length > 0 ||
    plan.bonuses.length > 0
  )
}

// Ready-made reasons, so the log reads the same way for the same cause.
export const REASONS = [
  'Slack was down',
  'Site bug',
  'Journal landed on the wrong day',
  'Ill',
  'Family emergency',
  'Travelling with no internet',
  'Event reward',
]
