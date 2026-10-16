import { router } from '@inertiajs/svelte'
import { pet as petRoute } from '@/routes'
import luluEgg from '@/assets/onboarding/lulu-egg.png'
import samiEgg from '@/assets/onboarding/sami-egg.png'

// The desktop pet, shared between the onboarding (which picks it and hands it over) and DesktopPet (which lives on
// every signed-in page). `picked` shows the pet straight away while the save is in flight; `handoff` is where the
// onboarding's talking egg was on screen when the dialog ended, so the pet can fly out of that spot.
export const PET_EGGS: Record<string, string> = { lulu: luluEgg, sami: samiEgg }

// The talking egg's pose in the onboarding dialog, in design units (components/dialog/geometry.ts). The desktop pet
// is sized from it.
export const DIALOG_EGG = { width: 277, height: 370, offsetX: 10, offsetY: -45 }

export const petState = $state({
  picked: null as string | null,
  onboarding: false,
  handoff: null as DOMRect | null,
})

export function choosePet(value: string) {
  petState.picked = value
  router.patch(
    petRoute(),
    { pet: value },
    { preserveScroll: true, preserveState: true, only: ['auth', 'setup'] },
  )
}
