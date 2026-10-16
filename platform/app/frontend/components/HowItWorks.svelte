<script lang="ts">
  // The landing page's "how it works", on the night like the rest of the page: the steps on a dotted path running
  // straight down to Shenzhen, after crescent.hackclub.com's, with the words on one side of each numbered stop and a
  // companion at that stage of its growth on the other. The stops take turns, Lulu then Sami.
  // Each stop fills with gold as it scrolls up past a little below the middle of the screen; the path stays as it is.
  // The steps follow program/the-plan.md without its numbers, which aren't settled.
  import lulu1 from '@/assets/pets/lulu/lulu-1.webp'
  import lulu2 from '@/assets/pets/lulu/lulu-2.webp'
  import lulu3 from '@/assets/pets/lulu/lulu-3.webp'
  import lulu4 from '@/assets/pets/lulu/lulu-4.webp'
  import sami1 from '@/assets/pets/sami/sami-1.webp'
  import sami2 from '@/assets/pets/sami/sami-2.webp'
  import sami3 from '@/assets/pets/sami/sami-3.webp'
  import sami4 from '@/assets/pets/sami/sami-4.webp'

  // each companion's four forms; the one standing at a form alternates, Lulu then Sami
  const companions = [
    [lulu1, lulu2, lulu3, lulu4],
    [sami1, sami2, sami3, sami4],
  ]

  // form: which of the companion's four forms stands by the stop; the first stop has none yet
  const steps = [
    {
      title: 'Pick a project',
      text: 'Choose that one big project you have been imagining!',
      form: null,
    },
    {
      title: 'Build in the huddle',
      text: 'Join the 24/7 huddle in #fallen on Slack. Set a goal for the session and get making!',
      form: 0,
    },
    { title: 'Journal', text: 'When you leave, post what you did in #fallen-journals on Slack.', form: 1 },
    {
      title: 'Level up',
      text: 'Every journal earns XP, and a streak multiplies it. Keep going until your companion reaches its final form.',
      form: 2,
    },
  ]
  const numerals = ['I', 'II', 'III', 'IV', 'V']
  const goal = { title: 'Visit Shenzhen!', text: 'Come to Shenzhen, or spend your XP in the shop!' }
  // each form's height
  const heights = ['h-32 lg:h-40', 'h-40 lg:h-52', 'h-48 lg:h-64', 'h-56 lg:h-80']

  // The path joins the stops' centres in straight lines, measured relative to the list whenever its size changes.
  let list: HTMLElement | undefined = $state()
  let listWidth = $state(0)
  let listHeight = $state(0)
  let nodes: HTMLElement[] = $state([])

  const points = $derived.by(() => {
    void [listWidth, listHeight]
    if (!list) return []
    const box = list.getBoundingClientRect()
    return nodes.filter(Boolean).map((node) => {
      const r = node.getBoundingClientRect()
      return [r.left + r.width / 2 - box.left, r.top + r.height / 2 - box.top]
    })
  })
  const route = $derived(points.map(([x, y], i) => `${i ? 'L' : 'M'}${x} ${y}`).join(''))

  // A stop is lit once it has scrolled above 60% of the way down the screen, and stays lit above the top. The
  // browser watches that line, so scrolling runs no script here.
  let lit: boolean[] = $state([])
  $effect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const { target, isIntersecting, boundingClientRect } of entries)
          lit[nodes.indexOf(target as HTMLElement)] = isIntersecting || boundingClientRect.top < 0
      },
      { rootMargin: '0px 0px -40% 0px' },
    )
    for (const node of nodes) if (node) observer.observe(node)
    return () => observer.disconnect()
  })
</script>

{#snippet stop(i: number)}
  <!-- a diamond with barely rounded corners and the step's numeral, hollow until the path reaches it -->
  <span
    bind:this={nodes[i]}
    class={[
      'relative z-1 grid size-10 rotate-45 place-items-center rounded-xs border-2 border-gold font-lora text-base font-bold transition duration-500',
      lit[i]
        ? 'bg-gold text-dark-blue shadow-[0_0_5px_color-mix(in_oklab,var(--color-gold)_35%,transparent)]'
        : 'bg-blue text-gold',
    ]}
  >
    <span class="-rotate-45">{numerals[i]}</span>
  </span>
{/snippet}

{#snippet standing(form: number | null, align: string)}
  <!-- the companion at this stage, standing on a soft dark shadow; nothing before it has hatched -->
  {#if form !== null}
    <div class="flex items-end {align}" aria-hidden="true">
      <!-- the halo and shadow sit in the companion's own box, so they stay centred on it whichever side it's on: lit
           from behind by the sky's bright blue, and standing on a soft dark shadow -->
      <div class="relative max-w-full">
        <div
          class="absolute -inset-x-[15%] -top-[5%] bottom-0 rounded-full bg-[radial-gradient(closest-side,color-mix(in_oklab,var(--color-bright-blue)_55%,transparent),transparent)]"
        ></div>
        <div class="absolute inset-x-[10%] -bottom-1 h-6 rounded-[50%] bg-black/55 blur-md"></div>
        <img
          src={companions[form % 2][form]}
          alt=""
          loading="lazy"
          class="relative {heights[form]} w-auto max-w-full object-contain object-bottom"
        />
      </div>
    </div>
  {/if}
{/snippet}

<section id="how-it-works" class="relative overflow-x-clip px-6 pt-32 pb-24 md:px-10">
  <hgroup class="relative flex flex-col items-center gap-4 text-center">
    <h2
      class="font-lora text-6xl font-bold text-parchment text-shadow-md text-shadow-dark-purple/40 md:text-7xl"
    >
      How it works
    </h2>
    <p class="max-w-lg font-lora text-xl text-pale-blue italic">
      Pick a character and evolve it to visit Shenzhen!
    </p>
  </hgroup>

  <div
    bind:this={list}
    bind:clientWidth={listWidth}
    bind:clientHeight={listHeight}
    class="relative mx-auto mt-14 max-w-5xl"
  >
    <svg class="pointer-events-none absolute inset-0 size-full overflow-visible" aria-hidden="true">
      <path
        d={route}
        fill="none"
        class="stroke-gold/60"
        stroke-width="2.5"
        stroke-dasharray="0 9"
        stroke-linecap="round"
      />
    </svg>

    <ol class="relative flex flex-col gap-10 lg:gap-0">
      {#each steps as step, i (step.title)}
        {@const left = i % 2 === 0}
        <!-- narrow: the stop on the left, the words and companions beside it. Wide: three columns, the words on one
             side, the companions on the other, and the stop in the middle on the path -->
        <li
          class="grid grid-cols-[3rem_1fr] items-start gap-x-5 lg:min-h-44 lg:grid-cols-[1fr_6rem_1fr] lg:items-center lg:gap-x-8"
        >
          <div class="col-start-1 row-start-1 flex justify-center pt-1 lg:col-start-2 lg:pt-0">
            {@render stop(i)}
          </div>
          <div class={['col-start-2 row-start-1', left ? 'lg:col-start-1 lg:text-right' : 'lg:col-start-3']}>
            <h3
              class="font-lora text-2xl font-bold text-cream text-shadow-md text-shadow-dark-purple/40 lg:text-3xl"
            >
              {step.title}
            </h3>
            <p class={['mt-2 max-w-sm font-semibold text-pale-blue/80', left && 'lg:ml-auto']}>{step.text}</p>
          </div>
          <div
            class={['col-start-2 mt-4 lg:row-start-1 lg:mt-0', left ? 'lg:col-start-3' : 'lg:col-start-1']}
          >
            {@render standing(step.form, left ? 'lg:justify-start' : 'lg:justify-end')}
          </div>
        </li>
      {/each}

      <!-- the goal, centred where the path ends, with the companions in their final forms -->
      <li
        class="grid grid-cols-[3rem_1fr] gap-x-5 lg:mt-6 lg:flex lg:flex-col lg:items-center lg:text-center"
      >
        <div class="flex justify-center pt-1">{@render stop(steps.length)}</div>
        <div class="min-w-0 lg:mt-6">
          <h3 class="font-lora text-3xl font-bold text-shadow-md text-shadow-dark-purple/40 lg:text-4xl">
            {goal.title}
          </h3>
          <p class="mt-2 text-pale-blue/80">{goal.text}</p>
          <div class="mt-6">{@render standing(3, 'lg:justify-center')}</div>
        </div>
      </li>
    </ol>
  </div>
</section>
