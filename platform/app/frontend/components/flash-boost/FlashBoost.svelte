<script lang="ts">
  import DialogStage from '@/components/dialog/DialogStage.svelte'
  import type { Character, DialogScript } from '@/components/dialog/types'
  import { COLORS, DRAWINGS } from '@/components/welcome-back/WelcomeBack.svelte'
  import { PET_FORMS, PET_NAMES } from '@/lib/pet.svelte'
  import type { Boost } from './FlashBoostOverlay.svelte'

  // The flash event (FlashBoost), told by the person's pet in the welcome back's dialog: what their team gets and
  // when it ends. Only for hatched pets (FlashBoostOverlay skips eggs), growing with each form as on the landing page;
  // the name tag and text move over for the wide ones (DialogStage `clearAvatar`).
  let {
    pet,
    form,
    boost,
    multiplier,
    onclose,
  }: {
    pet: string
    form: number
    boost: Boost
    multiplier: number
    onclose: () => void
  } = $props()

  // Each form's height on the landing page (HowItWorks, h-48 to h-88 at lg) in px, scaled into the dialog's design
  // units (dialog/geometry.ts), the widest drawings held to MAX_WIDTH so the text keeps room beside them.
  const LANDING_HEIGHTS = [192, 240, 288, 352]
  const SCALE = 1.4
  const MAX_WIDTH = 600

  function character(pet: string, form: number): Character {
    const [w, h] = DRAWINGS[pet][form - 1]
    const scale = Math.min((LANDING_HEIGHTS[form - 1] * SCALE) / h, MAX_WIDTH / w)
    const avatar = { src: PET_FORMS[pet][form], width: Math.round(w * scale), height: Math.round(h * scale) }
    return { id: 'pet', name: PET_NAMES[pet], color: COLORS[pet], avatars: { happy: avatar } }
  }

  const fmt = (n: number) => `${Number(n.toFixed(2))}×`

  // "started 2 hours ago", or "just started" in its first minute (and in a development preview before it starts).
  function started(at: string) {
    const minutes = Math.floor((Date.now() - new Date(at).getTime()) / 60_000)
    if (minutes < 1) return 'just started'
    const ago = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' })
    if (minutes < 60) return `started ${ago.format(-minutes, 'minute')}`
    if (minutes < 48 * 60) return `started ${ago.format(-Math.floor(minutes / 60), 'hour')}`
    return `started ${ago.format(-Math.floor(minutes / 1440), 'day')}`
  }

  // svelte-ignore state_referenced_locally
  const ends = new Date(boost.ends_at).toLocaleString(undefined, {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })

  // svelte-ignore state_referenced_locally
  const perk =
    pet === 'sami'
      ? `Every journal you write gets +${boost.sami_step} on your multiplier. That’s ${fmt(multiplier)} [arrow]→[/arrow] [wobble]${fmt(multiplier + boost.sami_step)}[/wobble]!`
      : `All the XP you earn from journals is multiplied by [wobble]${fmt(boost.lulu_factor)}[/wobble]!`

  // svelte-ignore state_referenced_locally
  const SCRIPT: DialogScript = {
    start: 'hi',
    nodes: [
      {
        id: 'hi',
        speaker: 'pet',
        text: '[shake]SURPRISE XP EVENT!!!!!!![/shake]',
        next: 'perk',
      },
      { id: 'perk', text: perk, next: 'when' },
      {
        id: 'when',
        text: `It lasts until midnight ET Sunday, that’s ${ends} for you!`,
        next: 'bye',
      },
      {
        id: 'bye',
        text: `It ${started(boost.starts_at)}, now go journal and ENJOYYY!!!! BYEEE`,
        next: 'got-this',
      },
      { id: 'got-this', text: 'u got this', next: 'for-real' },
      { id: 'for-real', text: 'okay bye for real!!', choices: [{ label: 'Bye!' }] },
    ],
  }
</script>

<DialogStage
  class="size-full"
  script={SCRIPT}
  characters={[character(pet, form)]}
  clearAvatar
  bottom={24}
  onComplete={onclose}
/>
