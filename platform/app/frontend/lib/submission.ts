import { csrfToken } from '@/lib/csrf'
import { bomImports, projectRepoSnapshots, projectSubmissionCheck, repoSnapshot } from '@/routes'
import type { RepoSnapshot } from '@/types'

// What the submit popup keeps while someone fills it in, saved in their browser so closing it loses nothing. A
// saved repository check may have gone stale; the server says so on send (RepoSnapshot::FRESH_FOR).
export type MadeWith = 'pcb' | 'cad' | 'firmware'
export type BomKind = 'part' | 'shipping' | 'tax'

export interface DraftItem {
  key: string
  kind: BomKind
  name: string
  purpose: string
  quantity: number
  // Typed as text so "3.5" and "" survive editing; turned into cents when sent.
  unit: string
  total: string
  link: string
  vendor: string
  owned: boolean
}

export interface Screenshot {
  id: string
  url: string
}

export interface SubmissionDraft {
  madeWith: MadeWith[]
  ready: boolean[]
  repoUrl: string
  // The link as typed when it was last checked, so editing it asks for a new check.
  checkedUrl: string
  snapshot: RepoSnapshot | null
  screenshots: Screenshot[]
  items: DraftItem[]
  bomCsv: string
  // The repository (its link as the server cleaned it up) and its bom.csv when it was last checked, so a later check
  // can tell whether the parts list belongs to a different repository or an older bom.csv.
  bomRepo: { url: string; csv: string } | null
  note: string
}

export interface Check {
  key: string
  label: string
  status: 'pass' | 'warn' | 'fail'
  detail: string | null
  doc?: string | null
}

export const MAX_SCREENSHOTS = 5
export const MAX_ITEMS = 200

export const emptyDraft = (repoUrl = ''): SubmissionDraft => ({
  madeWith: [],
  ready: [],
  repoUrl,
  checkedUrl: '',
  snapshot: null,
  screenshots: [],
  items: [],
  bomCsv: '',
  bomRepo: null,
  note: '',
})

const storageKey = (projectId: string) => `fallen:submission:${projectId}`

export function loadDraft(projectId: string, repoUrl: string): SubmissionDraft {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey(projectId)) ?? 'null')
    if (saved && Array.isArray(saved.items)) return { ...emptyDraft(repoUrl), ...saved }
  } catch {
    // A draft from an older version of the popup: start again.
  }
  return emptyDraft(repoUrl)
}

export function saveDraft(projectId: string, draft: SubmissionDraft) {
  try {
    localStorage.setItem(storageKey(projectId), JSON.stringify(draft))
  } catch {
    // Private mode or a full disk: the popup still works, it just won't remember.
  }
}

export function clearDraft(projectId: string) {
  localStorage.removeItem(storageKey(projectId))
}

let keys = 0
export const newKey = () => `row-${Date.now().toString(36)}-${keys++}`

export function blankItem(kind: BomKind = 'part'): DraftItem {
  return {
    key: newKey(),
    kind,
    name: kind === 'part' ? '' : kind === 'shipping' ? 'Shipping' : 'Tax',
    purpose: '',
    quantity: 1,
    unit: '',
    total: '',
    link: '',
    vendor: '',
    owned: false,
  }
}

// "$1,234.50", "3.5", "" -> cents, or null when there's no number.
export function toCents(text: string): number | null {
  const cleaned = text.replace(/[^0-9.]/g, '')
  if (!cleaned) return null
  const value = Number.parseFloat(cleaned)
  return Number.isFinite(value) ? Math.round(value * 100) : null
}

export function fromCents(cents: number | null | undefined): string {
  if (cents == null) return ''
  return cents % 100 === 0 ? String(cents / 100) : (cents / 100).toFixed(2)
}

export function money(cents: number | null | undefined): string {
  const value = (cents ?? 0) / 100
  return value.toLocaleString('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: Number.isInteger(value) ? 0 : 2,
  })
}

// A line's total: what's typed in the total, else the unit price times the quantity.
export function lineCents(item: DraftItem): number | null {
  const total = toCents(item.total)
  if (total != null) return total
  const unit = toCents(item.unit)
  return unit == null ? null : unit * Math.max(item.quantity, 1)
}

export const requestedCents = (items: DraftItem[]) =>
  items.reduce((sum, item) => sum + (item.owned ? 0 : (lineCents(item) ?? 0)), 0)

// What the server takes: BomItem::FIELDS.
export function itemPayload(item: DraftItem) {
  const total = lineCents(item) ?? 0
  return {
    kind: item.kind,
    name: item.name.trim(),
    purpose: item.purpose.trim() || null,
    quantity: Math.max(1, Math.round(item.quantity) || 1),
    unit_cents: toCents(item.unit) ?? (item.quantity > 0 ? Math.round(total / item.quantity) : null),
    total_cents: total,
    link: item.link.trim() || null,
    vendor: item.vendor.trim() || null,
    owned: item.owned,
  }
}

// Why a line can't be sent yet, or null when it's fine: the server says the same (SubmissionChecks).
export function itemProblem(item: DraftItem): string | null {
  if (!item.name.trim()) return 'Needs a name'
  if (item.kind !== 'part' || item.owned) return null
  if (lineCents(item) == null || lineCents(item) === 0) return 'Needs a price'
  if (!item.link.trim()) return 'Needs a link to buy it'
  if (!/^https?:\/\/\S+$/.test(item.link.trim())) return 'The link must start with https://'
  return null
}

async function postJson<T>(url: string, body: unknown): Promise<T> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken() },
    credentials: 'same-origin',
    body: JSON.stringify(body),
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(data.error ?? `Something went wrong (${response.status}). Try again.`)
  return data as T
}

// Starts reading the repository and waits until it's read (RepoSnapshotJob), up to about two minutes.
export async function checkRepository(
  projectId: string,
  url: string,
  onStart?: (s: RepoSnapshot) => void,
): Promise<RepoSnapshot> {
  let snapshot = await postJson<RepoSnapshot>(projectRepoSnapshots(projectId).url, { url })
  onStart?.(snapshot)
  const started = Date.now()
  while (snapshot.status === 'pending') {
    if (Date.now() - started > 150_000)
      throw new Error('Reading your repository is taking a while. Try again in a minute.')
    await new Promise((resolve) => setTimeout(resolve, Date.now() - started < 10_000 ? 1000 : 2500))
    const response = await fetch(repoSnapshot(snapshot.id).url, {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    })
    if (!response.ok) throw new Error(`Couldn't check on your repository (${response.status})`)
    snapshot = await response.json()
  }
  return snapshot
}

type ImportedItem = RepoSnapshot['bom_items'][number]

const toDraftItems = (items: ImportedItem[]): DraftItem[] =>
  items.map((item) => ({
    key: newKey(),
    kind: item.kind,
    name: item.name,
    purpose: item.purpose ?? '',
    quantity: item.quantity,
    unit: fromCents(item.unit_cents),
    total: fromCents(item.total_cents),
    link: item.link ?? '',
    vendor: item.vendor ?? '',
    owned: item.owned,
  }))

export async function importBom(csv: string): Promise<{ items: DraftItem[]; warnings: string[] }> {
  const data = await postJson<{ items: ImportedItem[]; warnings: string[] }>(bomImports.create().url, { csv })
  return { items: toDraftItems(data.items), warnings: data.warnings }
}

// The repository's bom.csv as parts rows. They're read in the background after the repository check
// (BomExtractionJob), so this waits for that; if it takes too long the file is read the quick way instead.
export async function repoBom(snapshot: RepoSnapshot): Promise<{ items: DraftItem[]; warnings: string[] }> {
  const started = Date.now()
  let current = snapshot
  while (current.bom_state === 'pending' && Date.now() - started < 120_000) {
    await new Promise((resolve) => setTimeout(resolve, 2000))
    const response = await fetch(repoSnapshot(snapshot.id).url, {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    })
    if (!response.ok) break
    current = await response.json()
  }
  if (current.bom_state === 'done' && current.bom_items.length > 0)
    return { items: toDraftItems(current.bom_items), warnings: current.bom_warnings }
  return importBom(snapshot.bom_csv ?? '')
}

export async function runChecks(projectId: string, draft: SubmissionDraft): Promise<Check[]> {
  const data = await postJson<{ checks: Check[] }>(projectSubmissionCheck(projectId).url, {
    snapshot_id: draft.snapshot?.id,
    made_with: draft.madeWith,
    screenshots: draft.screenshots.length,
    items: draft.items.map(itemPayload),
  })
  return data.checks
}
