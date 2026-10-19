import { router } from '@inertiajs/svelte'
import { toast } from 'svelte-sonner'

// For messages that never reach Rails, like a failed upload: toast.error('Upload failed.').
export { toast }

// Alerts stay up longer: they usually mean something has to be redone.
const ALERT_MS = 7000

// Rails' flash[:notice] / flash[:alert] arrive as Inertia page flash, which fires once per visit (not on deferred
// prop reloads or history navigation). Registered at import time so the first page's flash is not missed.
router.on('flash', (event) => {
  const { notice, alert } = event.detail.flash
  if (notice) toast.success(notice)
  if (alert) toast.error(alert, { duration: ALERT_MS })
})
