import { router } from '@inertiajs/svelte'
import { pet as petRoute } from '@/routes'
import luluEgg from '@/assets/onboarding/lulu-egg.png'
import samiEgg from '@/assets/onboarding/sami-egg.png'
import lulu1 from '@/assets/pets/lulu/lulu-1.webp'
import lulu2 from '@/assets/pets/lulu/lulu-2.webp'
import lulu3 from '@/assets/pets/lulu/lulu-3.webp'
import lulu4 from '@/assets/pets/lulu/lulu-4.webp'
import sami1 from '@/assets/pets/sami/sami-1.webp'
import sami2 from '@/assets/pets/sami/sami-2.webp'
import sami3 from '@/assets/pets/sami/sami-3.webp'
import sami4 from '@/assets/pets/sami/sami-4.webp'

// The desktop pet, shared between the onboarding (which picks it and hands it over) and DesktopPet (which lives on
// every signed-in page). `picked` shows the pet straight away while the save is in flight; `handoff` is where the
// onboarding's talking egg was on screen when the dialog ended, so the pet can fly out of that spot.

// Each pet's looks by form (User#pet_form): the egg, then the four stages.
export const PET_FORMS: Record<string, string[]> = {
  lulu: [luluEgg, lulu1, lulu2, lulu3, lulu4],
  sami: [samiEgg, sami1, sami2, sami3, sami4],
}
export const FINAL_FORM = 4
export const PET_NAMES: Record<string, string> = { lulu: 'Lulu', sami: 'Sami' }
export const PET_EGGS: Record<string, string> = { lulu: luluEgg, sami: samiEgg }

// The talking egg's pose in the onboarding dialog, in design units (components/dialog/geometry.ts). The desktop pet
// is sized from it.
export const DIALOG_EGG = { width: 277, height: 370, offsetX: 10, offsetY: -45 }

export const petState = $state({
  picked: null as string | null,
  onboarding: false,
  handoff: null as DOMRect | null,
  // Where the hatched pet stood when the hatch closed, for the desktop pet to fly out of.
  hatched: null as DOMRect | null,
  // The hatch playing over the window (components/hatch/HatchOverlay.svelte), and what to do when it ends.
  hatching: null as { pet: string; teaser: boolean; done: () => void } | null,
})

// `teaser` (development only, for recording a clip) cracks it once and leaves it rattling, never opening.
export function hatch(pet: string, { teaser = false } = {}) {
  return new Promise<void>((resolve) => {
    petState.hatching = {
      pet,
      teaser,
      done: () => {
        petState.hatching = null
        resolve()
      },
    }
  })
}

export function choosePet(value: string) {
  petState.picked = value
  router.patch(
    petRoute(),
    { pet: value },
    { preserveScroll: true, preserveState: true, only: ['auth', 'setup'] },
  )
}
