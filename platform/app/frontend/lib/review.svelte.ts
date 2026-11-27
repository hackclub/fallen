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
  // A design reviewer's decision held for an admin (SubmissionReview#propose), as it was sent. `at` names it exactly.
  proposal: { data: ProposedReview; at: string; by: Person | null } | null
  sent_back: { at: string; by: Person | null; to: Person | null } | null
  project: ReviewProject
  journals: ReviewJournal[]
  repo: ReviewRepo | null
  history: ReviewSubmission[]
  notes: ReviewerNote[]
  options: ReviewOptions
  claimed: boolean
  can: {
    decide: boolean
    // An admin signing off the held decision: they edit it here, and it's sent as the reviewer's review.
    sign_off: boolean
    take_over: boolean
    reject: boolean
    cut: boolean
    flag: boolean
    unflag: boolean
    note: boolean
  }
  skip: string
}

export type Answer = 'yes' | 'partly' | 'no'
export type Verdict = 'approved' | 'returned' | 'rejected'

// How much of a journal's time counts: all of it, or deflated to what's typed (0 for none). The choice is kept apart
// from the minutes, so typing a number never flips it back to all.
export type JournalMode = 'full' | 'part'

export interface JournalCall {
  mode: JournalMode | null
  // Only read for "part": what was entered, which may be unfinished or out of range while it's being typed.
  minutes: number | null
  reason: string | null
  note: string
  // Carried over from an earlier submission's review: shown, but the reviewer confirms it.
  carried: boolean
}

// What ticking "AI-generated journals" fills in (SubmissionReview's `ai`), for the reviewer to finish or send as is.
export const AI_INTERNAL = 'AI-generated journals: '
export const AI_FEEDBACK =
  "AI-generated journals are not allowed. We want to see your thoughts and progress, not AI's, so this project can't be funded."

export interface ReviewDraft {
  rubric: Record<string, Answer>
  journals: Record<string, JournalCall>
  feedback: string
  internal: string
  // Marked as AI-generated journals: it can only be rejected for good, and nothing else is needed.
  ai: boolean
  // Minutes off the whole project for staff only (SubmissionReview's `cut`): the person never sees it. Admins only.
  cut: number | null
}

// A held decision as the server keeps it (SubmissionReview#propose).
export interface ProposedReview {
  verdict: Verdict
  feedback: string | null
  internal_reason: string | null
  rubric: Record<string, Answer>
  journals: Record<string, { approved_minutes: number | null; reason: string | null; note: string | null }>
  ai: boolean
  cut: number | null
}

const key = (id: string) => `fallen:review:${id}`

// The review's starting point: what was decided (a finished review), what the last review of each journal decided,
// or counted in full. A half-done review comes back from the browser.
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
              // Counting it in full is the default anyway, so only a deflation needs confirming.
              carried: !decided && j.earlier.approved_minutes < (j.duration_minutes ?? 0),
            }
          : { mode: decided ? null : 'full', minutes: null, reason: null, note: '', carried: false },
      ]),
    ),
    feedback: submission.feedback ?? '',
    internal: submission.internal_reason ?? '',
    ai: submission.ai_generated,
    cut: submission.internal_deflated_minutes,
  }
  if (decided) return fresh
  const saved = newestSaved(page, fromProposal(page))
  if (!saved) return fresh
  try {
    return {
      rubric: { ...fresh.rubric, ...saved.rubric },
      journals: Object.fromEntries(
        Object.entries(fresh.journals).map(([id, call]) => {
          const kept = saved.journals?.[id]
          // A draft saved before journals counted in full by default left them undecided.
          if (!kept || (kept.mode == null && kept.minutes == null)) return [id, call]
          const logged = journals.find((j) => j.id === id)?.duration_minutes ?? 0
          // Older drafts had a "none" choice, which is now a deflation to 0.
          const minutes = (kept.mode as string) === 'none' ? 0 : kept.minutes
          const mode =
            kept.mode === 'full' || kept.mode === 'part' ? kept.mode : modeFor(minutes ?? 0, logged)
          return [id, { ...kept, mode, minutes, carried: kept.carried && mode === 'part' }]
        }),
      ),
      feedback: saved.feedback ?? '',
      internal: saved.internal ?? '',
      ai: saved.ai === true,
      cut: page.can.cut ? (saved.cut ?? fresh.cut) : fresh.cut,
    }
  } catch {
    return fresh
  }
}

// `proposalAt` names the held decision an admin's changes were made to (ReviewPage's proposal).
type Saved = Partial<ReviewDraft> & { savedAt?: number; proposalAt?: string }

// A held decision in the page's terms, so it opens as the reviewer sent it.
function fromProposal(page: ReviewPage): Saved | null {
  if (!page.proposal) return null
  const { data, at } = page.proposal
  return {
    rubric: data.rubric ?? {},
    journals: Object.fromEntries(
      page.journals.map((j) => {
        const call = data.journals?.[j.id]
        const minutes = call?.approved_minutes ?? null
        return [
          j.id,
          {
            mode: data.ai || minutes == null ? 'full' : modeFor(minutes, j.duration_minutes ?? 0),
            minutes,
            reason: call?.reason ?? null,
            note: call?.note ?? '',
            carried: false,
          },
        ]
      }),
    ),
    feedback: data.feedback ?? '',
    internal: data.internal_reason ?? '',
    ai: data.ai === true,
    cut: data.cut ?? null,
    savedAt: Date.parse(at),
  }
}

// The newer of what this browser kept and what the server has, so a review carries on from wherever it was left. A
// held decision is what the server has: only changes made in this browser since it was sent come before it.
function newestSaved(page: ReviewPage, proposal: Saved | null): Saved | null {
  let local: Saved | null = null
  try {
    local =
      typeof localStorage === 'undefined'
        ? null
        : JSON.parse(localStorage.getItem(key(page.submission.id)) ?? 'null')
  } catch {
    local = null
  }
  const server = proposal ?? (page.draft ? { ...page.draft.data, savedAt: Date.parse(page.draft.at) } : null)
  // Changes kept in this browser count only against the very decision they were made to, whatever the clocks say.
  if (page.proposal) return local?.proposalAt === page.proposal.at ? local : server
  if (local?.proposalAt) local = null
  if (!local) return server
  if (!server) return local
  return (local.savedAt ?? 0) >= (server.savedAt ?? 0) ? local : server
}

export function saveReviewDraft(id: string, draft: ReviewDraft, proposalAt?: string) {
  try {
    localStorage.setItem(key(id), JSON.stringify({ ...draft, savedAt: Date.now(), proposalAt }))
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

// The reviewer's decision as the review page holds it, to compare an admin's edits against.
export const proposedDraft = (page: ReviewPage): ReviewDraft | null =>
  fromProposal(page) as ReviewDraft | null

export const VERDICT_LABEL: Record<Verdict, string> = {
  approved: 'Approve',
  returned: 'Return',
  rejected: 'Reject for good',
}

// What an admin signing off has changed from the reviewer's decision, in the words SubmissionReview's note uses.
// `verdict` is the one they're about to send, when there is one.
export function signOffChanges(page: ReviewPage, draft: ReviewDraft) {
  const theirs = proposedDraft(page)
  if (!theirs) return { internal: false, feedback: false, rubric: 0, journals: 0, ai: false, cut: false }
  const minutes = (j: ReviewJournal, d: ReviewDraft) => (d.ai ? 0 : countedMinutes(j, d.journals[j.id]))
  const call = (j: ReviewJournal, d: ReviewDraft) => {
    const counted = minutes(j, d)
    const deflated = counted != null && counted < (j.duration_minutes ?? 0)
    const c = d.journals[j.id]
    return JSON.stringify(d.ai ? [0] : [counted, deflated ? c?.reason : null, (c?.note ?? '').trim()])
  }
  return {
    internal: theirs.internal.trim() !== draft.internal.trim(),
    feedback: theirs.feedback.trim() !== draft.feedback.trim(),
    rubric: Object.keys(page.options.rubric).filter((k) => theirs.rubric[k] !== draft.rubric[k]).length,
    journals: page.journals.filter((j) => call(j, theirs) !== call(j, draft)).length,
    ai: theirs.ai !== draft.ai,
    cut: (theirs.cut ?? null) !== (draft.cut ?? null),
  }
}

export const modeFor = (minutes: number, logged: number): JournalMode => (minutes >= logged ? 'full' : 'part')

// The minutes a call counts, or null while it isn't a whole answer: no choice yet, or a deflation with no time typed
// or one that isn't less than what was logged.
export function countedMinutes(journal: ReviewJournal, call: JournalCall | undefined): number | null {
  const logged = journal.duration_minutes ?? 0
  if (!call?.mode) return null
  if (call.mode === 'full') return logged
  return call.minutes != null && call.minutes >= 0 && call.minutes < logged ? call.minutes : null
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
export const journalNeedsReason = (call: JournalCall | undefined) => call?.mode === 'part' && !call.reason

export function itemRequested(item: { owned: boolean; total_cents: number }) {
  return item.owned ? 0 : item.total_cents
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
