<script module lang="ts">
  import type { Character, DialogScript } from '@/components/dialog/types'
  import egg from '@/assets/onboarding/egg.png'
  import luluEgg from '@/assets/onboarding/lulu-egg.png'
  import samiEgg from '@/assets/onboarding/sami-egg.png'
  import { DIALOG_EGG } from '@/lib/pet.svelte'

  // Sizes are design units (see dialog/geometry.ts); the drawings are about 555 x 741. Once picked, the chosen egg
  // takes over as the speaker (see eggLaunch.ts), so each egg is a pose.
  const POSE = DIALOG_EGG
  const EGG: Character = {
    id: 'egg',
    name: 'Egg',
    color: '#FF427D',
    defaultEmotion: 'egg',
    avatars: {
      egg: { src: egg, ...POSE },
      lulu: { src: luluEgg, ...POSE },
      sami: { src: samiEgg, ...POSE },
    },
  }

  const PICKED = 'Great choice! It hatches when you finish your first journal.'
  // Past these there is nothing left to skip but the egg, which everyone picks.
  const UNSKIPPABLE = ['skip', 'no-idea', 'made', 'joined', 'choose', 'picked-lulu', 'picked-sami']
  // While it points at making a project, the button skips just that, for people without an idea yet.
  const PROJECT_STEPS = ['project', 'create', 'again']
</script>

<script lang="ts">
  import DialogStage from '@/components/dialog/DialogStage.svelte'
  import type { PanelApi } from '@/components/dialog/types'
  import EggPicker from './EggPicker.svelte'
  import ProjectSpotlight from './ProjectSpotlight.svelte'
  import { usePage } from '@inertiajs/svelte'
  import { markIntroHeard, tour } from '@/lib/tour.svelte'
  import type { SharedProps } from '@/types'
  import { choosePet, petState } from '@/lib/pet.svelte'

  let { name, start, onclose }: { name: string; start: string; onclose: () => void } = $props()
  const page = usePage<SharedProps>()
  // svelte-ignore state_referenced_locally
  const userId = page.props.auth.user?.id
  // svelte-ignore state_referenced_locally
  const joinedWith = page.props.setup?.step === 'onboarding' ? page.props.setup.joined_with : null

  // The steps follow components/HowItWorks.svelte, which follows program/the-plan.md without its unsettled numbers.
  const SCRIPT: DialogScript = {
    // svelte-ignore state_referenced_locally
    start,
    nodes: [
      {
        id: 'hi',
        speaker: 'egg',
        text: 'Hi {{name}}! I’m an egg. Welcome to [wobble]Fallen[/wobble]!',
        choices: [
          { label: 'Hi egg!', next: 'pitch' },
          { label: 'Wait, eggs can talk?', next: 'talks' },
        ],
      },
      { id: 'talks', text: 'I’m a very [wobble]special[/wobble] egg. Anyway!', next: 'pitch' },
      {
        id: 'pitch',
        text: 'Build one big project and raise a pet. Get it to its final form to qualify for [wobble]Shenzhen[/wobble]!',
        next: 'huddle',
      },
      {
        id: 'huddle',
        text: 'There’s a 24/7 huddle in #fallen if you like building with others. Totally optional!',
        next: 'journal',
      },
      {
        id: 'journal',
        text: 'After each session, post what you did in #fallen-journals. Every journal earns you XP!',
        next: 'streak',
      },
      {
        id: 'streak',
        text: 'Keep a streak going and your XP [shake]multiplies[/shake].',
        choices: [
          { label: 'What’s XP for?', next: 'goal' },
          { label: 'Got it!', next: 'goal' },
        ],
      },
      {
        id: 'goal',
        text: 'XP grows your pet. Then come to Shenzhen, or spend your XP in the shop!',
        next: () => (joinedWith ? 'joined' : 'idea'),
      },
      // Joined a team's project from its link before the onboarding, so there is no project to make.
      {
        id: 'joined',
        speaker: 'egg',
        text: 'You’re already building [wobble]{{project}}[/wobble] with {{owner}}! You’ll journal your own sessions there and keep your own XP.',
        next: 'choose',
        onEnter: () => userId && markIntroHeard(userId),
      },
      // Asked outright, so nobody makes up a project just to get past this. Without an idea they go on to the egg.
      {
        id: 'idea',
        text: 'Time to start your project! Do you know what you want to build?',
        choices: [
          { label: 'Yes, let’s make it!', next: 'project' },
          { label: 'Not yet', next: 'no-idea', onSelect: () => (skippedFrom = 'project') },
        ],
        onEnter: () => userId && markIntroHeard(userId),
      },
      // Off to make the project: spotlights (ProjectSpotlight.svelte) lead to the Projects tab, then its create button.
      // The onboarding steps aside for the form and comes back on 'made' once the project exists, or on 'again' if
      // the form was closed without one (lib/tour.svelte.ts).
      {
        id: 'project',
        text: 'First, open your Projects.',
        panel: tabPanel,
      },
      { id: 'create', text: 'Now hit [wobble]Create Project[/wobble]!', panel: spotlightPanel },
      {
        id: 'again',
        speaker: 'egg',
        text: 'No rush! Click the glowing button whenever you’re ready.',
        panel: spotlightPanel,
      },
      {
        id: 'made',
        speaker: 'egg',
        text: 'Ooh, [wobble]{{project}}[/wobble]! That sounds awesome.',
        next: 'choose',
      },
      {
        id: 'choose',
        text: 'Every pet starts out as an egg, like me. [wobble]Pick yours![/wobble]',
        panel: eggPanel,
      },
      // The skip button: everything but the egg, since picking one is what finishes the onboarding. Changing their
      // mind goes back to the line they were on.
      {
        id: 'skip',
        speaker: 'egg',
        text: 'Skip everything? You’ll go straight to picking your egg. Everyone needs one!',
        choices: [{ label: 'Yes, skip it', next: 'choose' }, { label: 'No, keep going' }],
        next: () => skippedFrom,
      },
      {
        id: 'no-idea',
        speaker: 'egg',
        text: 'That’s okay, don’t make one up! Start your project from the Projects tab once an idea comes to you.',
        choices: [{ label: 'Skip it for now', next: 'choose' }, { label: 'Actually, I have one' }],
        next: () => skippedFrom,
      },
      { id: 'picked-lulu', emotion: 'lulu', text: PICKED, choices: [{ label: 'Let’s go!' }] },
      { id: 'picked-sami', emotion: 'sami', text: PICKED, choices: [{ label: 'Let’s go!' }] },
    ],
  }

  let stage = $state<ReturnType<typeof DialogStage>>()
  // svelte-ignore state_referenced_locally
  let skippedFrom = start === 'no-idea' ? 'again' : 'hi'
  const canSkip = $derived(stage && !UNSKIPPABLE.includes(stage.nodeId()))
  const atProject = $derived(stage && PROJECT_STEPS.includes(stage.nodeId()))

  function skip() {
    if (!stage) return
    skippedFrom = stage.nodeId()
    stage.jump(atProject ? 'no-idea' : 'skip')
  }

  // svelte-ignore state_referenced_locally
  const vars = {
    name,
    // On the page the form went to, or the server's note of it when the onboarding resumes somewhere else.
    project:
      (page.props.project as { title?: string } | undefined)?.title ??
      (page.props.setup?.step === 'onboarding' ? page.props.setup.project : null) ??
      'your project',
    owner: joinedWith ?? '',
  }

  // The talking egg does not leave with the dialog: it is hidden where it stands and the desktop pet flies out of
  // that spot (DesktopPet.svelte). Without a pick there is nothing to hand over.
  function finish() {
    const egg = [...document.querySelectorAll<HTMLElement>('[data-dialog-avatar]')].at(-1)
    if (egg && petState.picked) {
      petState.handoff = egg.getBoundingClientRect()
      egg.style.visibility = 'hidden'
    }
    petState.onboarding = false
    onclose()
  }
</script>

{#snippet tabPanel(api: PanelApi)}
  <ProjectSpotlight target="projects-tab" onarrive={() => api.go('create')} />
{/snippet}

{#snippet spotlightPanel()}
  <ProjectSpotlight target="new-project" />
{/snippet}

{#snippet eggPanel(api: PanelApi)}
  <EggPicker
    onpick={(value) => {
      api.ctx.setVar('egg', value)
      choosePet(value)
      api.go(`picked-${value}`)
    }}
  />
{/snippet}

<DialogStage
  bind:this={stage}
  class="size-full {tour.spotlight ? 'pointer-events-none' : ''}"
  script={SCRIPT}
  characters={[EGG]}
  {vars}
  bottom={24}
  onComplete={finish}
/>

{#if canSkip}
  <!-- Keydown stays here so Enter on the button does not also advance the dialog. -->
  <button
    type="button"
    class="game-btn game-btn-white pointer-events-auto fixed top-[max(0.75rem,env(safe-area-inset-top))] right-3 z-10 min-h-11 px-5 text-base sm:top-5 sm:right-5 sm:text-lg"
    onclick={skip}
    onkeydown={(event) => event.stopPropagation()}
  >
    {atProject ? 'No idea yet?' : 'Skip intro'}
  </button>
{/if}
