// Menu sounds, made with Web Audio like the hatch's (components/hatch/sounds.ts): short soft blips, at the volume
// set in Settings.
import { MAX_VOLUME, loudness, preferences } from '@/lib/preferences.svelte'

let context: AudioContext | null = null
let master: GainNode

function audio() {
  if (!context) {
    context = new AudioContext()
    master = context.createGain()
    master.connect(context.destination)
  }
  master.gain.value = 0.35 * loudness()
  if (context.state === 'suspended') context.resume()
  return context
}

function tone(c: AudioContext, at: number, from: number, to: number, peak: number, length: number) {
  const osc = c.createOscillator()
  osc.type = 'triangle'
  osc.frequency.setValueAtTime(from, at)
  osc.frequency.exponentialRampToValueAtTime(to, at + length)
  const gain = c.createGain()
  gain.gain.setValueAtTime(0.0001, at)
  gain.gain.exponentialRampToValueAtTime(peak, at + 0.004)
  gain.gain.exponentialRampToValueAtTime(0.0001, at + length)
  osc.connect(gain).connect(master)
  osc.start(at)
  osc.stop(at + length + 0.05)
}

function play(notes: [delay: number, from: number, to: number, peak: number, length: number][]) {
  if (preferences.volume === 0) return
  const c = audio()
  for (const [delay, from, to, peak, length] of notes) tone(c, c.currentTime + delay, from, to, peak, length)
}

// The cursor moving onto something.
export const move = () => play([[0, 1320, 1250, 0.25, 0.04]])

export const select = () =>
  play([
    [0, 880, 880, 0.35, 0.06],
    [0.05, 1318.5, 1318.5, 0.35, 0.09],
  ])

export const toggle = (on: boolean) =>
  on
    ? play([
        [0, 659.25, 659.25, 0.35, 0.05],
        [0.045, 987.77, 987.77, 0.4, 0.08],
      ])
    : play([
        [0, 987.77, 987.77, 0.3, 0.05],
        [0.045, 587.33, 587.33, 0.3, 0.08],
      ])

// One step of the volume bar, higher for louder, so you hear the level you picked.
export const step = (level: number) =>
  play([[0, 440 * 2 ** (level / MAX_VOLUME), 440 * 2 ** (level / MAX_VOLUME), 0.45, 0.07]])

export const confirm = () => play([523.25, 659.25, 783.99, 1046.5].map((f, i) => [i * 0.06, f, f, 0.3, 0.25]))

export const cancel = () => play([[0, 392, 330, 0.3, 0.1]])

// A rising hum while something is held; stop() cuts it off.
export function charge(seconds: number) {
  if (preferences.volume === 0) return { stop() {} }
  const c = audio()
  const t = c.currentTime
  const osc = c.createOscillator()
  osc.type = 'triangle'
  osc.frequency.setValueAtTime(220, t)
  osc.frequency.exponentialRampToValueAtTime(880, t + seconds)
  const gain = c.createGain()
  gain.gain.setValueAtTime(0.0001, t)
  gain.gain.exponentialRampToValueAtTime(0.16, t + seconds)
  osc.connect(gain).connect(master)
  osc.start(t)
  return {
    stop() {
      const now = c.currentTime
      gain.gain.cancelScheduledValues(now)
      gain.gain.setValueAtTime(Math.max(gain.gain.value, 0.0001), now)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.06)
      osc.stop(now + 0.1)
    },
  }
}
