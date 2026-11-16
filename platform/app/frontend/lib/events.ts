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
  { start: '2026-11-16T12:00-05:00', end: '2026-11-16T13:30-05:00', title: 'Hardware help', host: 'DS010' },
  { start: '2026-11-16T18:00-05:00', end: '2026-11-16T19:30-05:00', title: 'Game sesh', host: 'Ayush' },
  { start: '2026-11-17T12:00-05:00', end: '2026-11-17T13:30-05:00', title: 'Game sesh', host: 'Ayush' },
  { start: '2026-11-18T12:00-05:00', end: '2026-11-18T13:30-05:00', title: 'Yap time', host: 'Rehan' },
  {
    start: '2026-11-19T18:00-05:00',
    end: '2026-11-19T22:00-05:00',
    title: 'Hardware help',
    host: 'santiagocuenta112az',
  },
  {
    start: '2026-11-20T20:00-05:00',
    end: '2026-11-20T22:30-05:00',
    title: 'Yap time',
    host: 'santiagocuenta112az',
  },
  { start: '2026-11-21T12:00-05:00', end: '2026-11-21T13:30-05:00', title: 'Hardware help', host: 'Ayush' },
  { start: '2026-11-21T19:00-05:00', end: '2026-11-21T20:00-05:00', title: 'Game sesh', host: 'Qweezi' },
  { start: '2026-11-22T12:00-05:00', end: '2026-11-22T13:30-05:00', title: 'Yap time', host: 'Rehan' },
  { start: '2026-11-22T21:00-05:00', end: '2026-11-22T22:00-05:00', title: 'Game sesh', host: 'Qweezi' },
]
