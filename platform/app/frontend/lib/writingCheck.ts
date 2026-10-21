import { csrfToken } from '@/lib/csrf'
import { writingCheck, writingChecks } from '@/routes'

// WritingChecksController: Pangram's read on a journal's writing, asked for when it's about to be posted. An error
// or a slow answer resolves to an unflagged result (or null), so the journal posts as if nothing was checked.
export type WritingCheck = {
  id: string
  status: 'pending' | 'done' | 'failed' | 'skipped' | 'limited'
  flagged: boolean
}

const POLL_EVERY = 700
const GIVE_UP_AFTER = 15_000

async function request(url: string, signal: AbortSignal, init: RequestInit = {}) {
  const response = await fetch(url, {
    ...init,
    signal,
    credentials: 'same-origin',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken() },
  })
  if (!response.ok) throw new Error(`Writing check failed (${response.status})`)
  return (await response.json()) as WritingCheck
}

export async function checkWriting(body: string, signal: AbortSignal): Promise<WritingCheck | null> {
  const giveUp = Date.now() + GIVE_UP_AFTER
  try {
    let check = await request(writingChecks.create().url, signal, {
      method: 'POST',
      body: JSON.stringify({ body }),
    })
    while (check.status === 'pending' && Date.now() < giveUp) {
      await new Promise((resolve) => setTimeout(resolve, POLL_EVERY))
      check = await request(writingCheck(check.id).url, signal)
    }
    return check
  } catch {
    return null
  }
}
