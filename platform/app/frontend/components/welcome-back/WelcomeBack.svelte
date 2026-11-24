<script module lang="ts">
  import { DIALOG_EGG, PET_FORMS, PET_NAMES } from '@/lib/pet.svelte'
  import type { AvatarSpec, Character } from '@/components/dialog/types'

  // Each form's drawing size (assets/pets), fitted into the dialog at the first forms' height in design units
  // (dialog/geometry.ts), no wider than MAX_WIDTH.
  export const DRAWINGS: Record<string, [number, number][]> = {
    lulu: [
      [306, 354],
      [385, 416],
      [520, 612],
      [680, 458],
    ],
    sami: [
      [299, 294],
      [400, 380],
      [520, 424],
      [680, 536],
    ],
  }
  const HEIGHT = 340
  // The speech bubble's text starts 268 units in (dialog/geometry.ts); wider and the final forms, which are drawn
  // much wider than tall, stand in front of it. The onboarding's egg is 287 at its widest.
  const MAX_WIDTH = 300
  export const COLORS: Record<string, string> = { lulu: '#F9AF3F', sami: '#353b7d' }

  function pose(pet: string, form: number): AvatarSpec {
    if (form === 0) return { src: PET_FORMS[pet][0], ...DIALOG_EGG }
    const [w, h] = DRAWINGS[pet][form - 1]
    const scale = Math.min(HEIGHT / h, MAX_WIDTH / w)
    return { src: PET_FORMS[pet][form], width: Math.round(w * scale), height: Math.round(h * scale) }
  }

  export interface Answers {
    pronouns: string
    reminder?: boolean
  }

  export function petCharacter(pet: string, form: number): Character {
    return { id: 'pet', name: PET_NAMES[pet], color: COLORS[pet], avatars: { happy: pose(pet, form) } }
  }
</script>

<script lang="ts">
  import DialogStage from '@/components/dialog/DialogStage.svelte'
  import type { Choice, DialogScript } from '@/components/dialog/types'
  import ProjectSpotlight from '@/components/onboarding/ProjectSpotlight.svelte'
  import { onDestroy } from 'svelte'
  import { animate, type AnimationPlaybackControls } from 'motion'
  import { prefersReducedMotion } from '@/components/dialog/motion'
  import { PRONOUNS } from '@/lib/pronouns'
  import { tour } from '@/lib/tour.svelte'

  // The welcome back (ApplicationController#welcome_back_props): their pet asks for their pronouns, then points at
  // the dashboard's Slack ping box (LockInReminder) and offers it if Slack can reach them and it isn't on already.
  let {
    name,
    pet,
    form,
    pronouns,
    remindable,
    reminderOn,
    hoursLeft,
    onclose,
  }: {
    name: string
    pet: string
    form: number
    pronouns: string | null
    remindable: boolean
    reminderOn: boolean
    hoursLeft: number
    onclose: (answers: Answers) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const answers: Answers = { pronouns: pronouns ?? '' }

  const pick = (value: string): Choice => ({
    label: value,
    next: 'thanks',
    onSelect: () => (answers.pronouns = value),
  })

  // Asked only when it can be turned on and isn't already; otherwise the pet just says where they stand, and a click
  // on the message moves on.
  // svelte-ignore state_referenced_locally
  const reminderChoices: Choice[] | undefined =
    remindable && !reminderOn
      ? [
          { label: 'Yes, ping me!', next: 'reminder-on', onSelect: () => (answers.reminder = true) },
          { label: 'No thanks', next: 'reminder-off' },
        ]
      : undefined
  // svelte-ignore state_referenced_locally
  const reminderNext = reminderOn ? 'already' : 'no-slack'

  // Glides the page down to the Slack ping box while the pet is still talking, and only then puts the spotlight on
  // it: the box goes to the middle of the room above the speech bubble. Room is added below the page so a box near
  // its foot can get there. Each frame sets the position outright, since html scrolls smoothly by default.
  const SCROLL_SECONDS = 1.1
  let scrolling: AnimationPlaybackControls | undefined
  let arrived = $state(false)
  // Where the page was before, to glide back to if they go back to the pronouns.
  let scrolledFrom = 0

  function glide(to: number, then: () => void) {
    const jump = (top: number) => scrollTo({ top, behavior: 'instant' })
    scrolling?.stop()
    scrolling = undefined
    if (prefersReducedMotion()) {
      jump(to)
      return then()
    }
    scrolling = animate(scrollY, to, { duration: SCROLL_SECONDS, ease: [0.65, 0, 0.35, 1], onUpdate: jump })
    // A glide cut short by the next one never runs its `then`.
    const current = scrolling
    current.finished.then(() => current === scrolling && then())
  }

  function scrollToBox() {
    const box = document.querySelector<HTMLElement>('[data-tour="lock-in-reminder"]')
    if (!box) return
    arrived = false
    scrolledFrom = scrollY
    document.body.style.paddingBottom = `${innerHeight}px`
    const bubble =
      document.querySelector('[data-dialog-bubble]')?.getBoundingClientRect().top ?? innerHeight / 2
    const r = box.getBoundingClientRect()
    glide(Math.max(0, scrollY + r.top + r.height / 2 - bubble / 2), () => (arrived = true))
  }

  const SPOTLIT = ['pings', 'pings-how']
  // No going back from the start or from the question itself.
  const NO_BACK = ['hi', 'pronouns']
  let stage = $state<ReturnType<typeof DialogStage>>()
  const node = $derived(stage?.nodeId())
  const spotlit = $derived(arrived && !!node && SPOTLIT.includes(node))
  const canGoBack = $derived(!!node && !NO_BACK.includes(node))

  // Back to the pronoun question, with the reminder asked afresh, and the page back where it was.
  function back() {
    arrived = false
    answers.reminder = undefined
    tour.lastHole = null
    stage?.jump('pronouns')
    glide(scrolledFrom, () => (document.body.style.paddingBottom = ''))
  }

  onDestroy(() => {
    scrolling?.stop()
    document.body.style.paddingBottom = ''
  })

  // svelte-ignore state_referenced_locally
  const SCRIPT: DialogScript = {
    start: 'hi',
    nodes: [
      {
        id: 'hi',
        speaker: 'pet',
        text: 'Welcome back, {{name}}! Quick question first.',
        next: 'pronouns',
      },
      {
        id: 'pronouns',
        text: 'What pronouns should we use for you?',
        choices: [...PRONOUNS.map(pick), { label: 'Skip', next: 'thanks' }],
      },
      { id: 'thanks', text: 'Got it, thanks!', next: 'pings' },
      {
        id: 'pings',
        text: 'Now look, something new! This box gets you Slack pings to help you [wobble]lock in[/wobble].',
        choices: [{ label: 'What do they do?', next: 'pings-how' }],
        onEnter: scrollToBox,
      },
      {
        id: 'pings-how',
        text: `I’ll ping you in your team’s channel when your day has ${hoursLeft} hours left and you haven’t journaled yet.`,
        choices: reminderChoices,
        next: reminderNext,
      },
      { id: 'reminder-on', text: 'You’re in! Untick that box any time to stop.', next: 'bye' },
      { id: 'reminder-off', text: 'Okay! That box is always here if you change your mind.', next: 'bye' },
      { id: 'already', text: 'You’re already getting them! Untick that box any time to stop.', next: 'bye' },
      { id: 'no-slack', text: 'Connect Slack in Settings first, so I can reach you.', next: 'bye' },
      { id: 'bye', text: 'See you around!', choices: [{ label: 'Bye!' }] },
    ],
  }
</script>

<!-- Beside the dialog rather than a node's panel, since a panel would hold the dialog until it moves it on. -->
{#if spotlit}
  <ProjectSpotlight target="lock-in-reminder" />
{/if}

{#if canGoBack}
  <!-- Keydown stays here so Enter on the button does not also advance the dialog. -->
  <button
    type="button"
    class="game-btn game-btn-white pointer-events-auto fixed top-[max(0.75rem,env(safe-area-inset-top))] left-3 z-10 min-h-11 px-5 text-base sm:top-5 sm:left-5 sm:text-lg"
    onclick={back}
    onkeydown={(event) => event.stopPropagation()}
  >
    ← Back
  </button>
{/if}

<DialogStage
  bind:this={stage}
  class="size-full {tour.spotlight ? 'pointer-events-none' : ''}"
  script={SCRIPT}
  characters={[petCharacter(pet, form)]}
  vars={{ name }}
  bottom={24}
  onComplete={() => onclose(answers)}
/>
