import type { User } from '@/types/serializers'

export type * from '@/types/serializers'

// Rails' flash[:notice] / flash[:alert], sent by inertia_rails as page flash rather than a prop.
declare module '@inertiajs/core' {
  export interface InertiaConfig {
    flashDataType: { notice?: string; alert?: string }
  }
}

// Props shared with every page from ApplicationController#inertia_share.
export interface SharedProps {
  auth: { user: User | null }
  impersonation: { impersonator_name: string } | null
  // ApplicationController#setup_props. `project` is the title of one made during the onboarding, if any.
  setup:
    | { step: 'onboarding'; project: string | null; rules: TeamRules }
    | { step: 'verify'; email: string }
    | { step: 'slack' }
    | null
  lapse_configured: boolean
  // Development only, for replaying the onboarding after a pet is picked.
  team_rules: TeamRules | null
  errors: Record<string, string[]>
  [key: string]: unknown
}

// Team.rules: the numbers behind each team's reward.
export interface TeamRules {
  lulu_days: number
  lulu_bonus: number
  sami_step: number
  sami_max: number
  sami_freezes: number
  win_bonus: number
  xp_per_hour: number
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
