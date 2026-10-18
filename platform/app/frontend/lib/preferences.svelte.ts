const KEY = 'fallen:preferences'
export const MAX_VOLUME = 10

const defaults = { pet: true, volume: 6 }

function initial() {
  if (typeof window === 'undefined') return defaults
  try {
    return { ...defaults, ...JSON.parse(localStorage.getItem(KEY) ?? '{}') }
  } catch {
    return defaults
  }
}

// Settings that only change how this browser looks and sounds, so they stay on the device (pages/Settings/Show).
export const preferences = $state<typeof defaults>(initial())

export function setPreference<K extends keyof typeof defaults>(key: K, value: (typeof defaults)[K]) {
  preferences[key] = value
  localStorage.setItem(KEY, JSON.stringify(preferences))
}

export const loudness = () => preferences.volume / MAX_VOLUME

// Settings' "call it back": DesktopPet hops home when it hears this.
export const PET_HOME_EVENT = 'fallen:pet-home'
