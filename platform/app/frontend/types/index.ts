import type { User } from '@/types/serializers'

export type * from '@/types/serializers'

// Props shared with every page from ApplicationController#inertia_share.
export interface SharedProps {
  auth: { user: User | null }
  impersonation: { impersonator_name: string } | null
  flash: { notice?: string; alert?: string }
  errors: Record<string, string[]>
  [key: string]: unknown
}

export interface Pagy {
  count: number
  page: number
  limit: number
  pages: number
  next: number | null
  prev: number | null
}

// Shared by Admin::ApplicationController#inertia_share. Deferred, so missing on the first render.
export interface AdminStats {
  users_count: number
  projects_count: number
}

export interface AdminSharedProps extends SharedProps {
  admin_stats?: AdminStats
}
