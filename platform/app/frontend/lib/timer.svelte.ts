import { router } from '@inertiajs/svelte'
import { huddleInvite, huddlePauses, timers } from '@/routes'
import type { RouteDefinition } from '@/routes/runtime'
import type { TrackedTime } from '@/types'

// The pet's timer (components/PetTimer.svelte): the time put in since the last journal, from the huddle and the
// site's own timer (TrackedTime on the server). The server says when it changes over Action Cable (TimerChannel),
// so joining the huddle shows within a second; the page then asks for the time. It also asks on every page
// visit, whenever the socket (re)connects, and every POLL_EVERY in case a message was missed. Ticks locally
// between answers while counting.
//
// Answers can arrive out of order (a slow poll after a click). Each request is numbered and an answer older than
// the last one applied is dropped, so nothing on screen goes backwards.
const POLL_EVERY = 60_000
const RECONNECT_MAX = 30_000

export type Running = 'huddle' | 'timer' | 'paused' | null

export const timer = $state({
  loaded: false,
  seconds: 0,
  running: null as Running,
  inHuddle: false,
  huddleUrl: null as string | null,
  canRing: false,
  // Which prompt is open: joining the huddle (HuddlePrompt), or pausing while in it (PausePrompt).
  prompt: null as 'join' | 'pause' | 'leave' | null,
  // When `seconds` was last set, for ticking between answers.
  at: 0,
})

let sent = 0
let applied = 0

function csrfToken() {
  const cookie = document.cookie.match(/(?:^|; )XSRF-TOKEN=([^;]*)/)?.[1]
  return cookie
    ? decodeURIComponent(cookie)
    : (document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? '')
}

async function call(route: RouteDefinition<'get' | 'post' | 'delete'>) {
  const number = ++sent
  const response = await fetch(route.url, {
    method: route.method.toUpperCase(),
    headers: { Accept: 'application/json', 'X-CSRF-Token': csrfToken() },
    credentials: 'same-origin',
  })
  if (!response.ok) throw new Error(`${route.url} answered ${response.status}`)
  if (response.status === 202) return
  const time: TrackedTime = await response.json()
  if (number < applied) return
  applied = number
  timer.seconds = time.seconds
  timer.running = (['huddle', 'timer', 'paused'] as const).find((value) => value === time.running) ?? null
  timer.inHuddle = time.in_huddle
  timer.huddleUrl = time.huddle_url
  timer.canRing = time.can_ring
  timer.at = Date.now()
  timer.loaded = true
}

const refresh = () => call(timers.show()).catch(() => {})

// --- Action Cable, just enough of it -------------------------------------------------------------------------
// Subscribes to TimerChannel and refreshes on every message. Reconnects with backoff; every (re)connect
// refreshes too, since messages sent while it was down are gone.
function listen() {
  const identifier = JSON.stringify({ channel: 'TimerChannel' })
  let socket: WebSocket | undefined
  let retry: ReturnType<typeof setTimeout> | undefined
  let failures = 0
  let stopped = false

  const open = () => {
    const url = `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/cable`
    socket = new WebSocket(url, ['actioncable-v1-json', 'actioncable-unsupported'])
    socket.onmessage = (event) => {
      const message = JSON.parse(event.data)
      if (message.type === 'welcome') socket?.send(JSON.stringify({ command: 'subscribe', identifier }))
      else if (message.type === 'confirm_subscription') {
        failures = 0
        refresh()
      } else if (message.identifier === identifier && message.message) refresh()
      else if (message.type === 'disconnect' && message.reconnect === false) stopped = true
    }
    socket.onclose = () => {
      if (stopped) return
      retry = setTimeout(open, Math.min(RECONNECT_MAX, 1000 * 2 ** failures++))
    }
  }
  open()
  return () => {
    stopped = true
    clearTimeout(retry)
    socket?.close()
  }
}

// Starts watching; the returned function stops. DesktopPet calls it while the pet is shown.
export function watchTimer() {
  refresh()
  const poll = setInterval(() => !document.hidden && refresh(), POLL_EVERY)
  const onVisible = () => !document.hidden && refresh()
  document.addEventListener('visibilitychange', onVisible)
  const stopVisits = router.on('success', () => refresh())
  const stopListening = listen()
  return () => {
    clearInterval(poll)
    document.removeEventListener('visibilitychange', onVisible)
    stopVisits()
    stopListening()
  }
}

// The seconds to show now, counting on from the last answer while something is counting. Pass a clock that
// changes every second to make it tick.
export function shownSeconds(now: number) {
  const counting = timer.running === 'huddle' || timer.running === 'timer'
  return timer.seconds + (counting ? Math.max(0, Math.floor((now - timer.at) / 1000)) : 0)
}

// "04:09" under an hour, "01:04:09" past it.
export function formatTracked(total: number) {
  const pad = (n: number) => String(n).padStart(2, '0')
  const hours = Math.floor(total / 3600)
  const rest = `${pad(Math.floor((total % 3600) / 60))}:${pad(total % 60)}`
  return hours ? `${pad(hours)}:${rest}` : rest
}

// Shows a change straight away; the server's answer follows and wins.
function guess(running: Running) {
  timer.seconds = shownSeconds(Date.now())
  timer.at = Date.now()
  timer.running = running
  applied = ++sent
}

export function startTimer() {
  timer.prompt = null
  guess('timer')
  call(timers.create()).catch(refresh)
}

export function stopTimer() {
  guess(null)
  call(timers.destroy()).catch(refresh)
}

// Stay in the huddle, stop counting.
export function pauseHuddle() {
  timer.prompt = null
  guess('paused')
  call(huddlePauses.create()).catch(refresh)
}

export function resumeHuddle() {
  guess('huddle')
  call(huddlePauses.destroy()).catch(refresh)
}

// "Invite me": rings them into the huddle. The prompt's link opens it as well; the socket says when they are in.
export function inviteToHuddle() {
  timer.prompt = null
  call(huddleInvite()).catch(() => {})
}
