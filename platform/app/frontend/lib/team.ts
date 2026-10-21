import type { Person } from '@/types'

// TeamProps#team_props: who is on a project's team and what each has logged on it. Invites, the join link and the
// seats left are only sent to the team.
export type Teammate = Person & { owner: boolean; minutes: number; journals: number }

export interface TeamStatus {
  people: Teammate[]
  max: number
  invites?: { id: string; invitee: Person }[]
  join_url?: string
  open_seats?: number
}

// The one rule, worded the same wherever a team is joined or grown.
export const CREDIT_RULE =
  'Everyone journals their own sessions, and the hours and XP of a journal go only to whoever wrote it.'
