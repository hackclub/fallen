import BriefcaseBusiness from '@lucide/svelte/icons/briefcase-business'
import FolderOpen from '@lucide/svelte/icons/folder-open'
import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard'
import Users from '@lucide/svelte/icons/users'
import { adminProjects, adminRoot, adminUsers } from '@/routes'
import type { AdminStats } from '@/types'

export type AdminNavItem = {
  label: string
  href: string
  icon: typeof LayoutDashboard
  statKey?: keyof AdminStats
  // Not an Inertia page (mounted engine), so it needs a full page load.
  external?: boolean
}

export type AdminNavSection = { title: string; items: AdminNavItem[] }

// The sidebar and the command palette both read this.
export const adminNav: AdminNavSection[] = [
  { title: 'Navigation', items: [{ label: 'Dashboard', href: adminRoot().url, icon: LayoutDashboard }] },
  {
    title: 'Data',
    items: [
      { label: 'Projects', href: adminProjects.index().url, icon: FolderOpen, statKey: 'projects_count' },
      { label: 'Users', href: adminUsers.index().url, icon: Users, statKey: 'users_count' },
    ],
  },
  {
    title: 'System',
    items: [{ label: 'Jobs', href: '/admin/jobs', icon: BriefcaseBusiness, external: true }],
  },
]

export function isActive(item: AdminNavItem, pathname: string): boolean {
  const root = adminRoot().url
  return pathname === item.href || (item.href !== root && pathname.startsWith(item.href))
}
