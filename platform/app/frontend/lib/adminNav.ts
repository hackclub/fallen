import Bot from '@lucide/svelte/icons/bot'
import BriefcaseBusiness from '@lucide/svelte/icons/briefcase-business'
import ChartLine from '@lucide/svelte/icons/chart-line'
import Flag from '@lucide/svelte/icons/flag'
import Flame from '@lucide/svelte/icons/flame'
import FolderOpen from '@lucide/svelte/icons/folder-open'
import ArrowLeftRight from '@lucide/svelte/icons/arrow-left-right'
import Gauge from '@lucide/svelte/icons/gauge'
import Goal from '@lucide/svelte/icons/goal'
import Trophy from '@lucide/svelte/icons/trophy'
import LayoutDashboard from '@lucide/svelte/icons/layout-dashboard'
import Users from '@lucide/svelte/icons/users'
import ClipboardCheck from '@lucide/svelte/icons/clipboard-check'
import NotebookPen from '@lucide/svelte/icons/notebook-pen'
import Star from '@lucide/svelte/icons/star'
import ShieldAlert from '@lucide/svelte/icons/shield-alert'
import Banknote from '@lucide/svelte/icons/banknote'
import CalendarCheck from '@lucide/svelte/icons/calendar-check'
import Stamp from '@lucide/svelte/icons/stamp'
import {
  adminFlags,
  adminGrants,
  adminInsights,
  adminJobs,
  adminMcp,
  adminProjects,
  adminQualifying,
  adminSignOffs,
  adminRoot,
  adminStats,
  adminStreaks,
  adminTeams,
  adminTransfers,
  adminUsers,
  adminWorkshopRsvps,
  aiFlaggedProjects,
  journalReviewRoot,
  reviewSubmissions,
  starredProjects,
} from '@/routes'
import type { AdminStats } from '@/types'

export type AdminNavItem = {
  label: string
  href: string
  icon: typeof LayoutDashboard
  statKey?: keyof AdminStats
  // The count is a problem to look at, not a total, so it stands out (and hides at zero).
  alert?: boolean
  // The role besides admin that can open it (design_reviewer, reviewer). Everything without one is for admins only
  // (the server refuses everyone else either way).
  role?: Role
}

type Role = 'design_reviewer' | 'reviewer'
type PanelUser = { is_admin: boolean; roles: string[] } | null | undefined

export type AdminNavSection = { title: string; items: AdminNavItem[] }

// The sidebar and the command palette both read this.
export const adminNav: AdminNavSection[] = [
  {
    title: 'Navigation',
    items: [
      { label: 'Dashboard', href: adminRoot().url, icon: LayoutDashboard },
      { label: 'Stats', href: adminStats.show().url, icon: ChartLine },
      { label: 'Team stats', href: adminTeams.show().url, icon: Trophy },
      { label: 'Qualifying', href: adminQualifying.show().url, icon: Goal },
    ],
  },
  {
    title: 'Data',
    items: [
      { label: 'Projects', href: adminProjects.index().url, icon: FolderOpen, statKey: 'projects_count' },
      { label: 'Users', href: adminUsers.index().url, icon: Users, statKey: 'users_count' },
      { label: 'Transfers', href: adminTransfers.index().url, icon: ArrowLeftRight, role: 'reviewer' },
      { label: 'Streaks', href: adminStreaks.index().url, icon: Flame },
      {
        label: 'Design review',
        href: reviewSubmissions.reviewRoot().url,
        icon: ClipboardCheck,
        role: 'design_reviewer',
      },
      { label: 'Sign-offs', href: adminSignOffs.index().url, icon: Stamp },
      { label: 'Journal review', href: journalReviewRoot().url, icon: NotebookPen, role: 'reviewer' },
      { label: 'Starred projects', href: starredProjects().url, icon: Star, role: 'reviewer' },
      { label: 'AI flags', href: aiFlaggedProjects().url, icon: ShieldAlert, role: 'reviewer' },
      { label: 'Grants', href: adminGrants.index().url, icon: Banknote },
      { label: 'Workshop RSVPs', href: adminWorkshopRsvps.index().url, icon: CalendarCheck },
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
      { label: 'MCP', href: adminMcp.index().url, icon: Bot },
    ],
  },
]

// The panel as someone sees it: admins get all of it, reviewers only the queues their roles open.
export function navFor(user: PanelUser): AdminNavSection[] {
  if (user?.is_admin) return adminNav
  return adminNav
    .map((section) => ({
      ...section,
      items: section.items.filter((item) => item.role && user?.roles.includes(item.role)),
    }))
    .filter((section) => section.items.length > 0)
}

// Where the panel's logo goes: the dashboard for admins, the first queue they can open for everyone else.
export const panelHome = (user: PanelUser) =>
  user?.is_admin ? adminRoot().url : (navFor(user)[0]?.items[0]?.href ?? reviewSubmissions.reviewRoot().url)

export function isActive(item: AdminNavItem, pathname: string): boolean {
  const root = adminRoot().url
  return pathname === item.href || (item.href !== root && pathname.startsWith(item.href))
}
