const KEY = 'admin-dark'

function initial(): boolean {
  if (typeof window === 'undefined') return false
  const stored = localStorage.getItem(KEY)
  if (stored !== null) return stored === 'true'
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

// Admin dark mode, remembered per browser. AdminLayout puts `.dark` on its `.admin` wrapper.
export const adminDark = $state({ on: initial() })

export function toggleAdminDark() {
  adminDark.on = !adminDark.on
  localStorage.setItem(KEY, String(adminDark.on))
}
