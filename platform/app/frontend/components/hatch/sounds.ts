// The hatch's sounds, made with Web Audio so there are no files to download: a click of filtered noise over a
// knock for each crack, a rising hum while it charges, and a pop and a chime when it opens.

let context: AudioContext | null = null
let master: GainNode

function audio() {
  if (!context) {
    context = new AudioContext()
    master = context.createGain()
    master.gain.value = 0.45
    master.connect(context.destination)
  }
  if (context.state === 'suspended') context.resume()
  return context
}

function noise(c: AudioContext, seconds: number) {
  const buffer = c.createBuffer(1, Math.ceil(c.sampleRate * seconds), c.sampleRate)
  const data = buffer.getChannelData(0)
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1
  const source = c.createBufferSource()
  source.buffer = buffer
  return source
}

function envelope(c: AudioContext, at: number, peak: number, length: number, attack = 0.002) {
  const gain = c.createGain()
  gain.gain.setValueAtTime(0.0001, at)
  gain.gain.exponentialRampToValueAtTime(peak, at + attack)
  gain.gain.exponentialRampToValueAtTime(0.0001, at + length)
  gain.connect(master)
  return gain
}

function tone(
  c: AudioContext,
  at: number,
  type: OscillatorType,
  from: number,
  to: number,
  peak: number,
  length: number,
) {
  const osc = c.createOscillator()
  osc.type = type
  osc.frequency.setValueAtTime(from, at)
  osc.frequency.exponentialRampToValueAtTime(to, at + length)
  osc.connect(envelope(c, at, peak, length))
  osc.start(at)
  osc.stop(at + length + 0.05)
}

// Each crack is sharper than the last.
export function crack(strength: number) {
  const c = audio()
  const t = c.currentTime
  const snap = noise(c, 0.2)
  const band = c.createBiquadFilter()
  band.type = 'bandpass'
  band.frequency.value = 1600 + strength * 700
  band.Q.value = 1.4
  snap.connect(band).connect(envelope(c, t, 0.9, 0.09 + strength * 0.02))
  snap.start(t)
  tone(c, t, 'sine', 240 - strength * 25, 60, 0.6, 0.16)
}

export function land() {
  const c = audio()
  tone(c, c.currentTime, 'sine', 160, 45, 0.5, 0.22)
}

export function charge(seconds: number) {
  const c = audio()
  const t = c.currentTime
  const osc = c.createOscillator()
  osc.type = 'triangle'
  osc.frequency.setValueAtTime(180, t)
  osc.frequency.exponentialRampToValueAtTime(880, t + seconds)
  const gain = c.createGain()
  gain.gain.setValueAtTime(0.0001, t)
  gain.gain.exponentialRampToValueAtTime(0.18, t + seconds)
  gain.gain.exponentialRampToValueAtTime(0.0001, t + seconds + 0.05)
  osc.connect(gain).connect(master)
  osc.start(t)
  osc.stop(t + seconds + 0.1)
}

export function hatch() {
  const c = audio()
  const t = c.currentTime
  const pop = noise(c, 0.4)
  const low = c.createBiquadFilter()
  low.type = 'lowpass'
  low.frequency.setValueAtTime(3000, t)
  low.frequency.exponentialRampToValueAtTime(300, t + 0.3)
  pop.connect(low).connect(envelope(c, t, 1, 0.32))
  pop.start(t)
  tone(c, t, 'sine', 120, 40, 0.7, 0.3)
  // C major, up an octave and a bit
  ;[523.25, 659.25, 783.99, 1046.5, 1318.5].forEach((f, i) => {
    const at = t + 0.12 + i * 0.075
    tone(c, at, 'triangle', f, f, 0.22, 0.7)
    tone(c, at, 'sine', f * 2, f * 2, 0.06, 0.5)
  })
}
