import type { ColumnDef } from '@tanstack/table-core'
import ProjectCell from '@/components/admin/ProjectCell.svelte'
import RoleBadges from '@/components/admin/RoleBadges.svelte'
import UserCell from '@/components/admin/UserCell.svelte'
import { renderComponent } from '@/components/admin/ui/data-table'
import { formatDate, formatMinutes, timeAgo } from '@/lib/format'
import type { AdminProject, AdminUser } from '@/types'

// Column sets for DataTable, shared by the admin pages that list the same records.

export const userColumns: ColumnDef<AdminUser>[] = [
  {
    accessorKey: 'display_name',
    header: 'User',
    cell: ({ row }) => renderComponent(UserCell, { user: row.original }),
  },
  { accessorKey: 'slack_id', header: 'Slack ID', cell: ({ row }) => row.original.slack_id ?? '—' },
  {
    accessorKey: 'roles',
    header: 'Roles',
    enableSorting: false,
    cell: ({ row }) => renderComponent(RoleBadges, { roles: row.original.roles }),
  },
  {
    accessorKey: 'last_seen_at',
    header: 'Last seen',
    cell: ({ row }) => (row.original.last_seen_at ? timeAgo(row.original.last_seen_at) : 'never'),
  },
  { accessorKey: 'created_at', header: 'Joined', cell: ({ row }) => formatDate(row.original.created_at) },
]

export function projectColumns({ owner = true } = {}): ColumnDef<AdminProject>[] {
  return [
    {
      accessorKey: 'title',
      header: 'Project',
      cell: ({ row }) => renderComponent(ProjectCell, { project: row.original }),
    },
    ...(owner
      ? [
          {
            id: 'owner',
            accessorFn: (project: AdminProject) => project.user.display_name,
            header: 'Owner',
            cell: ({ row }) => renderComponent(UserCell, { user: row.original.user }),
          } satisfies ColumnDef<AdminProject>,
        ]
      : []),
    { accessorKey: 'journal_count', header: 'Journals' },
    {
      accessorKey: 'total_minutes',
      header: 'Hours',
      cell: ({ row }) => formatMinutes(row.original.total_minutes),
    },
    {
      id: 'slack',
      accessorFn: (project) => Boolean(project.slack_url),
      header: 'Slack',
      cell: ({ row }) => (row.original.slack_url ? 'Linked' : '—'),
    },
    { accessorKey: 'updated_at', header: 'Updated', cell: ({ row }) => timeAgo(row.original.updated_at) },
  ]
}
