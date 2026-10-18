<script module lang="ts">
  // The first forms posed like the onboarding's talking egg, in design units (dialog/geometry.ts). The drawings are
  // about 306 x 354 (Lulu) and 299 x 294 (Sami).
  const POSES: Record<string, { width: number; height: number; color: string }> = {
    lulu: { width: 294, height: 340, color: '#F9AF3F' },
    sami: { width: 346, height: 340, color: '#353b7d' },
  }
  const FLIGHT = 0.7 // s from the hatch to the dialog
  const ARC = 120 // px the flight bows up
  const HATCH_BACKDROP = 'bg-[radial-gradient(circle_at_50%_45%,rgba(22,32,100,0.94),rgba(0,1,5,0.97)_70%)]'

  const lerp = (a: number, b: number, t: number) => a + (b - a) * t
</script>

<script lang="ts">
  import { onMount } from 'svelte'
  import { animate } from 'motion'
  import DialogStage from '@/components/dialog/DialogStage.svelte'
  import { prefersReducedMotion, styler } from '@/components/dialog/motion'
  import type { Character, DialogScript } from '@/components/dialog/types'
  import { PET_FORMS, PET_NAMES, petState } from '@/lib/pet.svelte'

  // After the first hatch (EggHatch): the pet flies out of the hatch into a dialog, tells them about its message in
  // Slack (HatchCelebrationJob), then flies down into the desktop pet like the end of the onboarding.
  let { pet, from, onclose }: { pet: string; from: DOMRect; onclose: () => void } = $props()

  // svelte-ignore state_referenced_locally
  const name = PET_NAMES[pet]
  // svelte-ignore state_referenced_locally
  const src = PET_FORMS[pet][1]
  // svelte-ignore state_referenced_locally
  const { width, height, color } = POSES[pet]
  const PET: Character = { id: 'pet', name, color, avatars: { happy: { src, width, height } } }
  const SCRIPT: DialogScript = {
    start: 'congrats',
    nodes: [
      { id: 'congrats', speaker: 'pet', text: 'Congrats on finishing your first journal!!', next: 'slack' },
      { id: 'slack', text: 'I sent you a message on your project’s Slack thread :)', next: 'read' },
      { id: 'read', text: '[wobble]Go read it!![/wobble]', next: 'bye' },
      { id: 'bye', text: 'See you very soon :)', choices: [{ label: `Bye ${name}!` }] },
    ],
  }

  let root: HTMLElement
  let backdrop: HTMLElement
  let flier: HTMLImageElement

  onMount(() => {
    document.body.append(root)
    styler(backdrop).animate({ opacity: [1, 0] }, { duration: 0.6, ease: 'easeOut' })
    flyIn()
    return () => root.remove()
  })

  const avatar = () => root.querySelector<HTMLElement>('[data-dialog-avatar]')

  // Follows the avatar while it springs into place, so it lands where the avatar ends up.
  async function flyIn() {
    const target = avatar()
    if (!target || prefersReducedMotion()) return
    target.style.visibility = 'hidden'
    flier.hidden = false
    await animate(0, 1, {
      duration: FLIGHT,
      ease: [0.45, 0, 0.2, 1],
      onUpdate: (t) => {
        const to = target.getBoundingClientRect()
        Object.assign(flier.style, {
          left: `${lerp(from.left, to.left, t)}px`,
          top: `${lerp(from.top, to.top, t) - Math.sin(Math.PI * t) * ARC}px`,
          width: `${lerp(from.width, to.width, t)}px`,
          height: `${lerp(from.height, to.height, t)}px`,
        })
      },
    })
    target.style.visibility = ''
    flier.hidden = true
    if (target.parentElement)
      styler(target.parentElement).animate(
        { scaleY: [0.72, 1.12, 1], scaleX: [1.25, 0.94, 1] },
        { duration: 0.55, ease: [0.22, 1, 0.36, 1], times: [0, 0.45, 1] },
      )
  }

  // The pet does not leave with the dialog: it is hidden where it stands and the desktop pet flies out of that spot
  // (DesktopPet.svelte).
  async function finish() {
    const target = avatar()
    if (target && document.querySelector('[data-desktop-pet]')) {
      petState.hatched = target.getBoundingClientRect()
      target.style.visibility = 'hidden'
    }
    await styler(root).animate({ opacity: 0 }, { duration: 0.25 })
    onclose()
  }
</script>

<div
  bind:this={root}
  role="dialog"
  aria-modal="true"
  aria-label="{name} says hi"
  class="fixed inset-0 z-[70] bg-black/45"
>
  <div bind:this={backdrop} class={['pointer-events-none absolute inset-0', HATCH_BACKDROP]}></div>
  <DialogStage class="size-full" script={SCRIPT} characters={[PET]} bottom={24} onComplete={finish} />
  <img
    bind:this={flier}
    {src}
    alt=""
    hidden
    draggable="false"
    class="pointer-events-none fixed z-20 object-contain object-bottom"
  />
</div>
