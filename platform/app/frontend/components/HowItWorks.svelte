<script lang="ts">
  // The landing page's "how it works", on the night like the rest of the page: the steps on a dashed gold path running
  // straight down to Shenzhen, after crescent.hackclub.com's, with the words on one side of each starred stop and a
  // companion at that stage of its growth on the other. The stops take turns, Sami then Lulu.
  // The steps follow program/the-plan.md without its numbers, which aren't settled.
  import { starPath } from '@/components/GoldFrame.svelte'
  import { buildTime } from '@/lib/program'
  import lulu1 from '@/assets/pets/lulu/lulu-1.webp'
  import lulu2 from '@/assets/pets/lulu/lulu-2.webp'
  import lulu3 from '@/assets/pets/lulu/lulu-3.webp'
  import lulu4 from '@/assets/pets/lulu/lulu-4.webp'
  import sami1 from '@/assets/pets/sami/sami-1.webp'
  import sami2 from '@/assets/pets/sami/sami-2.webp'
  import sami3 from '@/assets/pets/sami/sami-3.webp'
  import sami4 from '@/assets/pets/sami/sami-4.webp'

  // each companion's four forms; the one standing at a form alternates, Sami then Lulu
  const companions = [
    [sami1, sami2, sami3, sami4],
    [lulu1, lulu2, lulu3, lulu4],
  ]
  // the light behind each: dark Sami gets a pale one to stand out against, pale Lulu the sky's bright blue
  const halos = [
    'bg-[radial-gradient(closest-side,color-mix(in_oklab,var(--color-pale-blue)_20%,transparent),transparent)]',
    'bg-[radial-gradient(closest-side,color-mix(in_oklab,var(--color-bright-blue)_55%,transparent),transparent)]',
  ]

  // form: which of the companion's four forms stands by the stop; the first stop has none yet
  const steps = [
    {
      title: 'Pick a project',
      text: `Choose a project that you can fully build within the next ${buildTime}.`,
      form: null,
    },
    {
      title: 'Build in the huddle',
      text: 'Join the 24/7 huddle in #fallen on Slack. Set a goal for the session and get making!',
      form: 0,
    },
    {
      title: 'Journal',
      text: 'When you end a session, post what you did in #fallen-journals on Slack!',
      form: 1,
    },
    {
      title: 'Level up',
      text: 'Every journal earns you XP, and your character will give you bonuses! Keep earning XP until your character has fully evolved!',
      form: 2,
    },
  ]
  const goal = { title: 'Visit Shenzhen!', text: 'Come to Shenzhen, or receive Fallen swag' }
  // each form's height
  const heights = ['h-32 lg:h-48', 'h-40 lg:h-60', 'h-48 lg:h-72', 'h-56 lg:h-88']

  // The path joins the stops in straight lines, measured relative to the list whenever its size changes. Each line
  // stops short of the stops at its ends, by a stop's radius and `gap` px more.
  const gap = 10
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
      return [r.left + r.width / 2 - box.left, r.top + r.height / 2 - box.top, r.width / 2]
    })
  })
  const route = $derived(
    points
      .slice(1)
      .map(([x2, y2, r2], i) => {
        const [x1, y1, r1] = points[i]
        const length = Math.hypot(x2 - x1, y2 - y1)
        const [dx, dy] = [(x2 - x1) / length, (y2 - y1) / length]
        const [a, b] = [r1 + gap, length - r2 - gap]
        return b > a ? `M${x1 + dx * a} ${y1 + dy * a}L${x1 + dx * b} ${y1 + dy * b}` : ''
      })
      .join(''),
  )

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
  <!-- a blue circle ringed in gold, with a gold star in it, turning tangerine once lit -->
  <span
    bind:this={nodes[i]}
    class={[
      'relative z-1 grid size-14 place-items-center rounded-full border-2 border-gold transition duration-500 motion-reduce:transition-none',
      lit[i]
        ? 'bg-tangerine text-cream shadow-[0_0_10px_color-mix(in_oklab,var(--color-tangerine)_45%,transparent)]'
        : 'bg-blue text-gold',
    ]}
  >
    <svg class="size-6 rotate-45" viewBox="0 0 29.1 29.1" aria-hidden="true"
      ><path d={starPath} fill="currentColor" /></svg
    >
  </span>
{/snippet}

{#snippet standing(form: number | null, align: string, who?: number, height?: string)}
  <!-- the companion at this stage (who: 0 for Sami, 1 for Lulu, taking turns by form if not given; height in place
       of the form's own), standing on a soft dark shadow; nothing before it has hatched -->
  {#if form !== null}
    {@const companion = who ?? form % 2}
    <div class="flex items-end {align}" aria-hidden="true">
      <!-- the halo and shadow sit in the companion's own box, so they stay centred on it whichever side it's on: lit
           from behind (see halos), and standing on a soft dark shadow -->
      <div class="relative max-w-full">
        <div class="absolute -inset-x-[15%] -top-[5%] bottom-0 rounded-full {halos[companion]}"></div>
        <div class="absolute inset-x-[10%] -bottom-1 h-6 rounded-[50%] bg-black/55 blur-md"></div>
        <img
          src={companions[companion][form]}
          alt=""
          loading="lazy"
          class="relative {height ?? heights[form]} w-auto max-w-full object-contain object-bottom"
        />
      </div>
    </div>
  {/if}
{/snippet}

<section id="how-it-works" class="relative overflow-x-clip px-8 pt-32 pb-24 sm:px-12 md:px-16 lg:px-20">
  <hgroup class="relative flex flex-col items-center gap-4 text-center">
    <h2
      class="font-lora text-4xl font-semibold text-tangerine text-shadow-md text-shadow-dark-purple/40 md:text-5xl lg:text-6xl"
    >
      How this works
    </h2>
    <p class="px-4 max-w-lg font-lora text-xl text-mint italic">
      Pick a character and evolve it to visit Shenzhen!
    </p>
  </hgroup>

  <div
    bind:this={list}
    bind:clientWidth={listWidth}
    bind:clientHeight={listHeight}
    class="relative mx-auto mt-14 max-w-7xl"
  >
    <!-- narrow, the stops are stacked over their words, so the path would run through them; it's only drawn wide -->
    <svg
      class="pointer-events-none absolute inset-0 hidden size-full overflow-visible lg:block"
      aria-hidden="true"
    >
      <path
        d={route}
        fill="none"
        class="stroke-gold/35"
        stroke-width="2"
        stroke-dasharray="3.5 7"
        stroke-linecap="round"
      />
    </svg>

    <ol class="relative flex flex-col gap-16 lg:gap-0">
      {#each steps as step, i (step.title)}
        {@const left = i % 2 === 0}
        <!-- narrow: one centred column, the stop over the words over the companion. Wide: three columns, the words on one
             side, the companions on the other, and the stop in the middle on the path. Wide rows are all one height,
             so the stops are evenly spaced; the tallest companion stands a little past its row -->
        <li
          class="grid justify-items-center gap-y-4 text-center lg:h-60 lg:grid-rows-1 lg:grid-cols-[1fr_6rem_1fr] lg:items-center lg:justify-items-stretch lg:gap-x-20 lg:gap-y-0 lg:text-left"
        >
          <div class="flex justify-center lg:col-start-2 lg:row-start-1">
            {@render stop(i)}
          </div>
          <div class={['lg:row-start-1', left ? 'lg:col-start-1 lg:text-right' : 'lg:col-start-3']}>
            <h3 class="font-lora text-3xl font-bold text-cream text-shadow-md text-shadow-dark-purple/40">
              {step.title}
            </h3>
            <p
              class={[
                'mx-auto mt-2 max-w-sm text-xl font-semibold text-pale-blue/80',
                left ? 'lg:mr-0' : 'lg:mx-0',
              ]}
            >
              {step.text}
            </p>
          </div>
          <div class={['lg:row-start-1', left ? 'lg:col-start-3' : 'lg:col-start-1']}>
            {@render standing(step.form, 'justify-center')}
          </div>
        </li>
      {/each}

      <!-- the goal, centred where the path ends, with the companions in their final forms. Its stop is a row's
           height (15rem) below the last one: half a row, the margin, its padding and half the stop -->
      <li class="flex flex-col items-center text-center lg:mt-22">
        <div class="flex justify-center pt-1">{@render stop(steps.length)}</div>
        <div class="mt-4 min-w-0 lg:mt-12">
          <h3
            class="font-lora text-3xl font-bold text-tangerine text-shadow-md text-shadow-dark-purple/40 lg:text-4xl"
          >
            {goal.title}
          </h3>
          <p class="mt-2 text-lg font-semibold text-pale-blue/80">{goal.text}</p>
          <!-- both, side by side: Sami, a little larger, then Lulu. They never wrap; on a narrow screen they keep their
               size and the sides are cut off. Only sideways, and with room either side, so their halos and shadows
               aren't -->
          <div class="-mx-24 mt-12 flex justify-center gap-x-10 overflow-x-clip px-24">
            {@render standing(3, 'shrink-0', 0, 'h-64 lg:h-96')}
            {@render standing(3, 'shrink-0', 1)}
          </div>
        </div>
      </li>
    </ol>
  </div>
</section>
