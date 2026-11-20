import { csrfToken } from '@/lib/csrf'
import type { Person, ReviewJournal, ReviewSubmission, ReviewerNote } from '@/types'

// The review page's props (ReviewPageProps on the server).
export interface ReviewRepo {
  url: string
  host: string
  branch: string
  commit_sha: string
  paths: string[]
  truncated: boolean
  readme: string | null
  readme_path: string | null
  bom_path: string | null
  bom_csv: string | null
  file_url_prefix: string | null
}

export interface ReviewOptions {
  rubric: Record<string, string>
  answers: Answer[]
  journal_reasons: string[]
  cut_reasons: string[]
  adjust_reasons: string[]
}

export interface ReviewProject {
  id: string
  title: string
  description: string | null
  slack_url: string | null
  team: Person[]
  created_at: string
  logged_minutes: number
  journal_count: number
}

export interface ReviewPage {
  submission: ReviewSubmission
  // An unfinished review saved on the server (Submission#save_review_draft), to carry on from.
  draft: { data: Partial<ReviewDraft>; at: string; by: Person | null } | null
  project: ReviewProject
  journals: ReviewJournal[]
  repo: ReviewRepo | null
  history: ReviewSubmission[]
  notes: ReviewerNote[]
  options: ReviewOptions
  claimed: boolean
  can: { decide: boolean; take_over: boolean; reject: boolean; flag: boolean; unflag: boolean; note: boolean }
  skip: string
}

export type Answer = 'yes' | 'partly' | 'no'
export type Verdict = 'approved' | 'returned' | 'rejected'
export type ItemVerdict = 'approved' | 'adjusted' | 'cut'

// How much of a journal's time counts. The choice is kept apart from the minutes, so typing a number for "part of
// it" never flips it to all or none.
export type JournalMode = 'full' | 'part' | 'none'

export interface JournalCall {
  mode: JournalMode | null
  // Only read for "part": what was entered, which may be unfinished or out of range while it's being typed.
  minutes: number | null
  reason: string | null
  note: string
  // Carried over from an earlier submission's review: shown, but the reviewer confirms it.
  carried: boolean
}

export interface ItemCall {
  verdict: ItemVerdict | null
  reason: string | null
  cents: number | null
  // The call the review that returned it made on the same part, for the reviewer to keep or change.
  carried?: boolean
}

// What ticking "AI-generated journals" fills in (SubmissionReview's `ai`), for the reviewer to finish or send as is.
export const AI_INTERNAL = 'AI-generated journals: '
export const AI_FEEDBACK =
  "AI-generated journals are not allowed. We want to see your thoughts and progress, not AI's, so this project can't be funded."

export interface ReviewDraft {
  rubric: Record<string, Answer>
  journals: Record<string, JournalCall>
  bom: Record<string, ItemCall>
  feedback: string
  internal: string
  // Marked as AI-generated journals: it can only be rejected for good, and nothing else is needed.
  ai: boolean
  // Minutes off the whole project for staff only (SubmissionReview's `cut`): the person never sees it.
  cut: number | null
}

const key = (id: string) => `fallen:review:${id}`

// The review's starting point: what was decided (a finished review), what the last review of each journal decided,
// or nothing yet. A half-done review comes back from the browser.
export function initialDraft(page: ReviewPage): ReviewDraft {
  const { submission, journals } = page
  const decided = submission.status !== 'pending'
  const fresh: ReviewDraft = {
    rubric: { ...submission.rubric },
    journals: Object.fromEntries(
      journals.map((j) => [
        j.id,
        j.earlier
          ? {
              mode: modeFor(j.earlier.approved_minutes, j.duration_minutes ?? 0),
              minutes: j.earlier.approved_minutes,
              reason: j.earlier.reason,
              note: j.earlier.note ?? '',
              carried: !decided,
            }
          : { mode: null, minutes: null, reason: null, note: '', carried: false },
      ]),
    ),
    bom: Object.fromEntries(
      submission.bom_items.map((item) => [
        item.id,
        (!decided && !item.verdict && earlierItemCall(page, item)) || {
          verdict: item.verdict,
          reason: item.reason,
          cents: item.approved_cents,
        },
      ]),
    ),
    feedback: submission.feedback ?? '',
    internal: submission.internal_reason ?? '',
    ai: submission.ai_generated,
    cut: submission.internal_deflated_minutes,
  }
  if (decided) return fresh
  const saved = newestSaved(page)
  if (!saved) return fresh
  try {
    return {
      rubric: { ...fresh.rubric, ...saved.rubric },
      journals: Object.fromEntries(
        Object.entries(fresh.journals).map(([id, call]) => {
          const kept = saved.journals?.[id]
          if (!kept) return [id, call]
          const logged = journals.find((j) => j.id === id)?.duration_minutes ?? 0
          return [
            id,
            { ...kept, mode: kept.mode ?? (kept.minutes == null ? null : modeFor(kept.minutes, logged)) },
          ]
        }),
      ),
      bom: Object.fromEntries(Object.entries(fresh.bom).map(([id, call]) => [id, saved.bom?.[id] ?? call])),
      feedback: saved.feedback ?? '',
      internal: saved.internal ?? '',
      ai: saved.ai === true,
      cut: saved.cut ?? fresh.cut,
    }
  } catch {
    return fresh
  }
}

type Saved = Partial<ReviewDraft> & { savedAt?: number }

// The newer of what this browser kept and what the server has, so a review carries on from wherever it was left.
function newestSaved(page: ReviewPage): Saved | null {
  let local: Saved | null = null
  try {
    local =
      typeof localStorage === 'undefined'
        ? null
        : JSON.parse(localStorage.getItem(key(page.submission.id)) ?? 'null')
  } catch {
    local = null
  }
  const server = page.draft ? { ...page.draft.data, savedAt: Date.parse(page.draft.at) } : null
  if (!local) return server
  if (!server) return local
  return (local.savedAt ?? 0) >= (server.savedAt ?? 0) ? local : server
}

export function saveReviewDraft(id: string, draft: ReviewDraft) {
  try {
    localStorage.setItem(key(id), JSON.stringify({ ...draft, savedAt: Date.now() }))
  } catch {
    // Storage full or off: the review still works, it just isn't kept.
  }
}

export function clearReviewDraft(id: string) {
  localStorage.removeItem(key(id))
}

// Keeps the server's copy of the review in step: a moment after each change, and straight away (`flush`) when the
// page is left, hidden or closed, with keepalive so the request outlives the page. `stop` ends it once the review
// is sent, so the decision is never followed by an old draft.
export function serverDraft(url: string) {
  let pending: ReviewDraft | null = null
  let timer: ReturnType<typeof setTimeout> | undefined
  let stopped = false

  const send = () => {
    clearTimeout(timer)
    if (!pending || stopped) return
    const body = JSON.stringify({ draft: pending })
    pending = null
    fetch(url, {
      method: 'PATCH',
      keepalive: body.length < 60_000,
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
      body,
    }).catch(() => {
      // Offline for a moment: the browser's copy still has it, and the next change sends it again.
    })
  }

  return {
    schedule(draft: ReviewDraft) {
      if (stopped) return
      pending = draft
      clearTimeout(timer)
      timer = setTimeout(send, 1200)
    },
    flush: send,
    stop() {
      stopped = true
      clearTimeout(timer)
      pending = null
    },
  }
}

export const modeFor = (minutes: number, logged: number): JournalMode =>
  minutes >= logged ? 'full' : minutes <= 0 ? 'none' : 'part'

// The minutes a call counts, or null while it isn't a whole answer: no choice yet, or "part of it" with a time that
// isn't between none and all.
export function countedMinutes(journal: ReviewJournal, call: JournalCall | undefined): number | null {
  const logged = journal.duration_minutes ?? 0
  if (!call?.mode) return null
  if (call.mode === 'full') return logged
  if (call.mode === 'none') return 0
  return call.minutes != null && call.minutes > 0 && call.minutes < logged ? call.minutes : null
}

// Ticking fills the reasons in where they're empty (a reason already written gets a button to add it, aiTemplate);
// unticking takes back what it filled in and wasn't changed.
export function markAi(draft: ReviewDraft, on: boolean) {
  draft.ai = on
  if (on) {
    if (!draft.internal.trim()) draft.internal = AI_INTERNAL
    if (!draft.feedback.trim()) draft.feedback = AI_FEEDBACK
  } else {
    if (draft.internal === AI_INTERNAL) draft.internal = ''
    if (draft.feedback === AI_FEEDBACK) draft.feedback = ''
  }
}

// Puts the template above what's already written.
export const aiTemplate = (text: string, template: string) =>
  text.includes(template.trim()) ? text : `${template.trim()}\n\n${text.trim()}`

export const journalDecided = (journal: ReviewJournal, call: JournalCall | undefined) =>
  countedMinutes(journal, call) != null && !call?.carried
export const journalDeflated = (journal: ReviewJournal, call: JournalCall | undefined) => {
  const counted = countedMinutes(journal, call)
  return counted != null && counted < (journal.duration_minutes ?? 0)
}
export const journalNeedsReason = (call: JournalCall | undefined) =>
  (call?.mode === 'part' || call?.mode === 'none') && !call.reason

// The call the last returned review made on a part of the same kind and name, if it made one.
function earlierItemCall(page: ReviewPage, item: Line & { kind: string; name: string }): ItemCall | null {
  if (item.owned) return null
  const key = (line: { kind: string; name: string }) => `${line.kind}:${line.name.trim().toLowerCase()}`
  const earlier = page.history
    .find((h) => h.status === 'returned')
    ?.bom_items.find((line) => line.verdict && key(line) === key(item))
  if (!earlier?.verdict) return null
  const cents =
    earlier.verdict === 'adjusted' &&
    earlier.approved_cents != null &&
    earlier.approved_cents < itemRequested(item)
      ? earlier.approved_cents
      : null
  return { verdict: earlier.verdict, reason: earlier.reason, cents, carried: true }
}

export function itemRequested(item: { owned: boolean; total_cents: number }) {
  return item.owned ? 0 : item.total_cents
}

type Line = { owned: boolean; total_cents: number }

// Whether a line has a whole call: a part they already own asks for nothing, so it needs none; a lowered one needs an
// amount between nothing and all of it.
export function itemDecided(item: Line, call: ItemCall | undefined) {
  if (item.owned) return true
  if (!call?.verdict || call.carried) return false
  if (call.verdict !== 'adjusted') return true
  return call.cents != null && call.cents > 0 && call.cents < itemRequested(item)
}

// The call the server gets for a line: owned parts go through as approved, for nothing.
export const itemVerdict = (item: Line, call: ItemCall | undefined) =>
  call?.verdict ?? (item.owned ? 'approved' : null)

export function itemFunded(item: Line, call: ItemCall | undefined) {
  if (item.owned) return 0
  if (!itemDecided(item, call)) return null
  if (call!.verdict === 'approved') return itemRequested(item)
  if (call!.verdict === 'cut') return 0
  return call!.cents!
}

// Fallout's raised buttons, over the admin Button's classes: a soft top-down gradient, a drop shadow and a 1px
// highlight along the top.
export const RAISED = {
  plain:
    'border-zinc-200 bg-linear-to-b from-white to-zinc-50 text-zinc-900 shadow-xs inset-shadow-2xs inset-shadow-white hover:bg-transparent hover:to-zinc-100 dark:border-zinc-700 dark:from-zinc-800 dark:to-zinc-900 dark:text-zinc-100 dark:inset-shadow-zinc-700',
  success:
    'border-emerald-700 bg-linear-to-b from-emerald-500 to-emerald-600 text-white shadow-sm inset-shadow-2xs inset-shadow-emerald-300 hover:bg-transparent hover:from-emerald-400 dark:border-emerald-500 dark:inset-shadow-emerald-400',
  warning:
    'border-amber-300 bg-linear-to-b from-amber-50 to-amber-100 text-amber-800 shadow-xs inset-shadow-2xs inset-shadow-white hover:bg-transparent hover:to-amber-200 dark:border-amber-700 dark:from-amber-900 dark:to-amber-950 dark:text-amber-200 dark:inset-shadow-amber-800',
  primary:
    'border-zinc-950 bg-linear-to-b from-zinc-700 to-zinc-900 text-white shadow-sm inset-shadow-2xs inset-shadow-zinc-500 hover:bg-transparent hover:from-zinc-600 dark:border-zinc-300 dark:from-zinc-100 dark:to-zinc-300 dark:text-zinc-900 dark:inset-shadow-white',
}
// The key hints inside them, matched to each face.
export const RAISED_KEY = {
  success: 'border-emerald-400 bg-emerald-600 text-emerald-50',
  warning:
    'border-amber-300 bg-amber-100 text-amber-600 dark:border-amber-700 dark:bg-amber-900 dark:text-amber-400',
}
