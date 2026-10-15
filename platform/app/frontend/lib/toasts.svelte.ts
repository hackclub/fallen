import { router } from '@inertiajs/svelte'

export type ToastKind = 'notice' | 'alert'

export interface Toast {
  id: number
  kind: ToastKind
  message: string
}

// Alerts stay up longer: they usually mean something has to be redone.
const VISIBLE_MS: Record<ToastKind, number> = { notice: 4000, alert: 7000 }

export const toasts = $state<Toast[]>([])

const timers = new Map<number, ReturnType<typeof setTimeout>>()
let nextId = 0

// For errors that never reach Rails, like a failed upload: toast('alert', 'Upload failed.').
export function toast(kind: ToastKind, message: string) {
  const id = nextId++
  toasts.push({ id, kind, message })
  timers.set(
    id,
    setTimeout(() => dismiss(id), VISIBLE_MS[kind]),
  )
}

export function dismiss(id: number) {
  clearTimeout(timers.get(id))
  timers.delete(id)
  const index = toasts.findIndex((t) => t.id === id)
  if (index !== -1) toasts.splice(index, 1)
}

// Rails' flash[:notice] / flash[:alert] arrive as Inertia page flash, which fires once per visit (not on deferred
// prop reloads or history navigation). Registered at import time so the first page's flash is not missed.
router.on('flash', (event) => {
  const { notice, alert } = event.detail.flash
  if (notice) toast('notice', notice)
  if (alert) toast('alert', alert)
})
