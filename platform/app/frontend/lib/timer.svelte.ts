import { router } from '@inertiajs/svelte'
import { huddleInvite, huddlePauses, huddlePrompt, timeCheckIn, timerWrapUp, timers } from '@/routes'
import type { RouteDefinition } from '@/routes/runtime'
import type { TrackedTime } from '@/types'
import { csrfToken } from '@/lib/csrf'

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
  // Their stopped site timer, waiting to be asked what they got done (TimerPrompt's wrapUp).
  wrapUp: null as TrackedTime['wrap_up'],
  // The hourly check-in waiting for an answer, also asked in their Slack DMs (TimerPrompt's checkIn).
  checkIn: null as TrackedTime['check_in'],
  maxHours: 0,
  // Which bubble TimerPrompt shows.
  prompt: null as 'join' | 'start' | 'wrapUp' | 'checkIn' | 'goal' | 'pause' | 'leave' | null,
  // When `seconds` was last set, for ticking between answers.
  at: 0,
})

let sent = 0
let applied = 0

// The check-in the pet last popped up for, so each one opens by itself once, even across reloads.
const CHECK_IN_ASKED = 'fallen:check-in-asked'
function askedAlready(id: string) {
  try {
    if (localStorage.getItem(CHECK_IN_ASKED) === id) return true
    localStorage.setItem(CHECK_IN_ASKED, id)
  } catch {
    /* storage unavailable: ask on every reload */
  }
  return false
}

// Throws the server's `error` for a refused answer (422), so a prompt can show it.
async function call(
  route: RouteDefinition<'get' | 'post' | 'patch' | 'delete'>,
  body?: Record<string, unknown>,
) {
  const number = ++sent
  const response = await fetch(route.url, {
    method: route.method.toUpperCase(),
    headers: {
      Accept: 'application/json',
      'X-CSRF-Token': csrfToken(),
      ...(body && { 'Content-Type': 'application/json' }),
    },
    credentials: 'same-origin',
    body: body && JSON.stringify(body),
  })
  if (response.status === 422) throw new Error((await response.json()).error)
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
  // A newly stopped timer asks what they got done once; closing the bubble leaves it for the next Start.
  if (time.wrap_up && !timer.wrapUp && !timer.prompt) timer.prompt = 'wrapUp'
  timer.wrapUp = time.wrap_up
  if (time.check_in && !timer.prompt && !askedAlready(time.check_in.id)) timer.prompt = 'checkIn'
  else if (!time.check_in && timer.prompt === 'checkIn') timer.prompt = null
  timer.checkIn = time.check_in
  timer.maxHours = time.max_hours
  timer.at = Date.now()
  timer.loaded = true
}

const refresh = () => call(timers.show()).catch(() => {})

// The tracked time as hours for a journal ("1.7", the way Duration.format writes them), asked for fresh. Empty
// when nothing was tracked or the server could not be reached.
export async function trackedHours() {
  await refresh()
  if (!timer.loaded) return ''
  const minutes = Math.floor(shownSeconds(Date.now()) / 60)
  return minutes > 0 ? String(Math.round((minutes / 60) * 100) / 100) : ''
}

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

// From the start bubble, with what they are working on. Rejects with the server's reason.
export async function startTimer(goal: string) {
  await call(timers.create(), { goal })
  timer.prompt = null
}

export function stopTimer() {
  guess(null)
  call(timers.destroy()).catch(refresh)
}

// What they got done and how many of the counted hours were work. Rejects with the server's reason.
export async function wrapUpTimer(answer: { done: string; hours: string }) {
  await call(timerWrapUp(), answer)
  timer.prompt = null
}

// What they have got done so far, for the hourly check-in. Rejects with the server's reason.
export async function answerCheckIn(done: string) {
  if (!timer.checkIn) return
  await call(timeCheckIn(timer.checkIn.id), { done })
  timer.prompt = null
}

// Stop from the check-in: the timer stops (and asks what they got done), the huddle asks whether to stay.
export function stopFromCheckIn() {
  if (timer.running === 'timer') {
    timer.prompt = null
    stopTimer()
  } else timer.prompt = 'pause'
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

// Start while chilling in the huddle: counts again, and Slack asks them what they are working on.
export function askGoal() {
  timer.prompt = 'goal'
  guess('huddle')
  call(huddlePrompt()).catch(refresh)
}

// "Invite me": rings them into the huddle. The prompt's link opens it as well; the socket says when they are in.
export function inviteToHuddle() {
  timer.prompt = null
  call(huddleInvite()).catch(() => {})
}
