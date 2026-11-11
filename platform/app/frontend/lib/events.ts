// This week's community calls, as posted in Slack. Replace the list each week. Times are written in Eastern (-05:00
// is EST, November to March; use -04:00 for EDT) and shown to each person in their own timezone.
export interface CommunityEvent {
  start: string
  end: string
  title: string
  host?: string
  note?: string
}

export const events: CommunityEvent[] = [
  { start: '2026-11-09T09:00-05:00', end: '2026-11-09T10:30-05:00', title: 'Roblox', host: 'Emanuel M' },
  { start: '2026-11-10T12:00-05:00', end: '2026-11-10T13:30-05:00', title: 'Game sesh', host: 'Ayush' },
  { start: '2026-11-11T12:00-05:00', end: '2026-11-11T13:30-05:00', title: 'Yap time', host: 'Rehan' },
  {
    start: '2026-11-11T19:00-05:00',
    end: '2026-11-11T21:00-05:00',
    title: 'Hardware review',
    host: 'migrantor main',
  },
  {
    start: '2026-11-12T17:00-05:00',
    end: '2026-11-12T22:00-05:00',
    title: 'Hardware help',
    host: 'santiagocuenta112az',
    note: '+ surprise',
  },
  { start: '2026-11-13T09:00-05:00', end: '2026-11-13T10:30-05:00', title: 'Show & tell', host: 'Ayush' },
  { start: '2026-11-14T12:00-05:00', end: '2026-11-14T13:30-05:00', title: 'Hardware help', host: 'DS010' },
  { start: '2026-11-14T19:00-05:00', end: '2026-11-14T20:00-05:00', title: 'Game sesh', host: 'Qweezi' },
  { start: '2026-11-15T12:00-05:00', end: '2026-11-15T13:30-05:00', title: 'Yap time', host: 'Vynu' },
  { start: '2026-11-15T19:00-05:00', end: '2026-11-15T20:00-05:00', title: 'Game sesh' },
]
