import BriefcaseBusiness from '@lucide/svelte/icons/briefcase-business'
import Flag from '@lucide/svelte/icons/flag'
import FolderOpen from '@lucide/svelte/icons/folder-open'
import Gauge from '@lucide/svelte/icons/gauge'
import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard'
import Users from '@lucide/svelte/icons/users'
import { adminFlags, adminInsights, adminJobs, adminProjects, adminRoot, adminUsers } from '@/routes'
import type { AdminStats } from '@/types'

export type AdminNavItem = {
  label: string
  href: string
  icon: typeof LayoutDashboard
  statKey?: keyof AdminStats
  // The count is a problem to look at, not a total, so it stands out (and hides at zero).
  alert?: boolean
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
    items: [
      {
        label: 'Jobs',
        href: adminJobs.index().url,
        icon: BriefcaseBusiness,
        statKey: 'failed_jobs_count',
        alert: true,
      },
      { label: 'Insights', href: adminInsights.show({}).url, icon: Gauge },
      { label: 'Flags', href: adminFlags.index().url, icon: Flag },
    ],
  },
]

export function isActive(item: AdminNavItem, pathname: string): boolean {
  const root = adminRoot().url
  return pathname === item.href || (item.href !== root && pathname.startsWith(item.href))
}
