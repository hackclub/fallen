import { router } from '@inertiajs/svelte'

// Where the onboarding is, kept outside any one page so it survives the visits it makes (a project page after the
// project is created). `start` is the dialog node it opens on; while it has `steppedAside` for the create-project
// form, nothing of it shows. Whether it opens, and where it picks up after someone leaves halfway, comes from the
// server's `setup` prop (OnboardingOverlay.svelte); the browser only remembers whether the intro was already heard.
export const tour = $state({
  open: false,
  start: 'hi',
  steppedAside: false,
  spotlight: false,
  // Where the spotlight's window last was, so the next step's window springs over from there.
  lastHole: null as { x: number; y: number; w: number; h: number } | null,
})

export function openTour(start = 'hi') {
  Object.assign(tour, { open: true, start, steppedAside: false, spotlight: false, lastHole: null })
}

export function closeTour() {
  Object.assign(tour, { open: false, start: 'hi', steppedAside: false, spotlight: false, lastHole: null })
}

// Holds the public id of whoever last heard the intro on this browser, so someone else signing in here hears it too.
const INTRO_HEARD = 'fallen:onboarding-intro'

export function markIntroHeard(userId: string) {
  localStorage.setItem(INTRO_HEARD, userId)
}

export function introHeard(userId: string) {
  return localStorage.getItem(INTRO_HEARD) === userId
}

// The person clicked the spotlit button: get out of the way of the form it opens and come back when it is done,
// on the new project if they made one, pointing at the button again if they changed their mind.
const FORM = '[aria-labelledby="create-project-title"]'

export function stepAside() {
  Object.assign(tour, { steppedAside: true, spotlight: false, start: 'again' })
  let seen = false
  const watch = setInterval(() => {
    if (!tour.steppedAside) return clearInterval(watch)
    const open = document.querySelector(FORM)
    if (open) seen = true
    else if (seen) {
      clearInterval(watch)
      // Creating the project closes the form and visits it; give that visit a moment to land first.
      setTimeout(() => tour.steppedAside && openTour('again'), 400)
    }
  }, 250)
}

router.on('navigate', (event) => {
  if (tour.steppedAside && event.detail.page.component === 'Projects/Show') openTour('made')
})
