<script lang="ts">
  // The landing page's FAQ: native <details>, so it works without JS. With it, one is open at a time and opening and
  // closing are animated: the answer's height eases open while its text fades and drops into place, and the
  // highlight and the ornament parting the line above follow `shown`, which changes on the click rather than when the
  // closing animation finishes.
  import DiamondOrnament from '@/components/DiamondOrnament.svelte'
  import { buildTime } from '@/lib/program'

  import type { Snippet } from 'svelte'

  const opening = { duration: 450, easing: 'cubic-bezier(0.22, 1, 0.36, 1)' }
  const closing = { duration: 280, easing: 'cubic-bezier(0.4, 0, 0.6, 1)' }

  let shown = $state(-1) // the open item; none to start with
  const items: HTMLDetailsElement[] = $state([])

  function toggle(event: MouseEvent, i: number) {
    event.preventDefault()
    const next = shown === i ? -1 : i
    items.forEach((item, j) => {
      if (j === next || j === shown) animate(item, j === next)
    })
    shown = next
  }

  // from wherever it is, so a click mid-animation turns it round instead of jumping
  function animate(item: HTMLDetailsElement, open: boolean) {
    const body = item.querySelector<HTMLElement>('[data-answer]')!
    // a closed item's answer is still laid out, just not shown
    const from = item.open ? body.getBoundingClientRect().height : 0
    for (const animation of body.getAnimations({ subtree: true })) animation.cancel()
    item.open = true
    const to = open ? body.scrollHeight : 0
    const timing = matchMedia('(prefers-reduced-motion: reduce)').matches
      ? { duration: 0 }
      : open
        ? opening
        : closing
    const height = body.animate({ height: [`${from}px`, `${to}px`] }, timing)
    body.firstElementChild!.animate(
      open
        ? { opacity: [0, 1], translate: ['0 -8px', '0 0'] }
        : { opacity: [1, 0], translate: ['0 0', '0 -4px'] },
      { ...timing, delay: open ? 70 : 0, fill: 'both' },
    )
    height.onfinish = () => {
      if (!open) item.open = false
      for (const animation of body.getAnimations({ subtree: true })) animation.cancel()
    }
  }

  const qualifyingHours = '90–110'

  const faqs: { question: string; answer: Snippet }[] = [
    { question: 'Who can join?', answer: whoCanJoin },
    { question: 'Is this legit?', answer: isItLegit },
    { question: "Is this really free? What's the catch?", answer: isItFree },
    { question: 'Why Shenzhen, China?', answer: whyShenzhen },
    { question: 'What do I build?', answer: whatToBuild },
    { question: 'Can I follow a tutorial?', answer: tutorials },
    { question: 'Can I work in teams?', answer: teams },
    { question: 'How long do I need to spend on my project?', answer: howLong },
    { question: "What if I can't go to Shenzhen?", answer: cantTravel },
    { question: "I've got more questions...", answer: moreQuestions },
  ]

  // bound rather than set, so updating `shown` never re-applies a stale open or closed state mid-animation
  const opened = $state(faqs.map((_, i) => i === shown))
</script>

{#snippet link(href: string, label: string)}
  <a
    {href}
    target="_blank"
    rel="noreferrer"
    class="text-cream underline decoration-gold/60 underline-offset-3">{label}</a
  >
{/snippet}

{#snippet whoCanJoin()}
  Any teenager aged 13 to 18 (inclusive)!
{/snippet}

{#snippet isItLegit()}
  Yes! {@render link('https://hackclub.com', 'Hack Club')} is a 501(c)(3) nonprofit, and we've run programs like
  {@render link('https://fallout.hackclub.com', 'Fallout')} and
  {@render link('https://outpost.hackclub.com', 'Outpost')} before.
{/snippet}

{#snippet isItFree()}
  Yes, no catch! Fallen funds your project and the in-person event.
{/snippet}

{#snippet whyShenzhen()}
  We'll be demoing our projects at Maker Faire Shenzhen, in the manufacturing capital of the world. While
  we're there, we'll visit local hardware spots like the world's largest electronics market.
{/snippet}

{#snippet whatToBuild()}
  One large hardware project (think a {buildTime} of dedicated work!). Keep in mind you'll be demoing this project
  in Shenzhen!
{/snippet}

{#snippet tutorials()}
  You can learn from tutorials, but your project must be your own.
{/snippet}

{#snippet teams()}
  Yes! Each teammate needs their own clear part of the project, and journals their own hours to level up their
  own character.
{/snippet}

{#snippet howLong()}
  Your character levels up with the hours you put in, and you qualify once it reaches its final form.
  Journaling every day builds a streak that speeds up its progress, so qualifying takes about {qualifyingHours}
  hours depending on how well you keep your streak.
{/snippet}

{#snippet cantTravel()}
  You can still take part! Level up your character to earn prizes like 3D printers and CNC mills, or custom
  Fallen merch.
{/snippet}

{#snippet moreQuestions()}
  Ask in {@render link('https://hackclub.enterprise.slack.com/archives/C0C9JQEPFL6', '#fallen-help')} on Slack or
  email us at {@render link('mailto:fallen@hackclub.com', 'fallen@hackclub.com')}!
{/snippet}

<section
  id="faq"
  class="flex flex-col justify-center gap-10 overflow-clip px-6 py-20 text-pale-blue md:px-20"
>
  <h2
    class="mx-auto font-lora text-6xl font-bold text-parchment text-shadow-md text-shadow-dark-purple/40 md:text-7xl"
  >
    FAQ
  </h2>
  <div class="place-down-stage flex justify-center gap-10">
    <div class="place-down place-down-stage mx-auto max-w-215 min-w-0 flex-1 py-12 md:px-8">
      {#each faqs as faq, i (faq.question)}
        <details
          bind:this={items[i]}
          bind:open={opened[i]}
          data-shown={shown === i || undefined}
          class="group place-down relative border-bright-blue/40 last-of-type:border-b-2"
          ontoggle={() => {
            // opened by the browser itself, as find in page does: catch up, closing the one that was open
            if (!items[i].open || shown === i) return
            if (shown >= 0) animate(items[shown], false)
            shown = i
          }}
        >
          <!-- the highlight, faded rather than switched, so it goes on and off with the answer -->
          <div
            class="pointer-events-none absolute inset-0 bg-linear-to-r from-transparent via-bright-blue/15 to-transparent opacity-0 transition-opacity duration-300 group-data-shown:opacity-100"
            aria-hidden="true"
          ></div>
          <summary
            class="relative flex cursor-pointer list-none items-center gap-4 px-4 py-5 font-lora text-xl font-semibold text-cream [&::-webkit-details-marker]:hidden md:px-6 md:text-2xl"
            onclick={(event) => toggle(event, i)}
          >
            {faq.question}
            <!-- The line above each item, in two halves that part for the ornament as the item opens. The panel behind
                 is a gradient, so nothing solid could fill the diamonds: the line stops short of them instead, and the
                 ornament is the line's colour at the same opacity. -->
            <span
              class="pointer-events-none absolute -top-0.5 right-1/2 left-0 h-0.5 bg-bright-blue/40 transition-[right] duration-500 ease-out group-data-shown:right-[calc(50%+24px)]"
              aria-hidden="true"
            ></span>
            <span
              class="pointer-events-none absolute -top-0.5 right-0 left-1/2 h-0.5 bg-bright-blue/40 transition-[left] duration-500 ease-out group-data-shown:left-[calc(50%+24px)]"
              aria-hidden="true"
            ></span>
            <DiamondOrnament
              class="pointer-events-none absolute -top-px left-1/2 z-10 -translate-1/2 scale-50 rotate-90 text-bright-blue opacity-0 transition duration-500 ease-out group-data-shown:scale-100 group-data-shown:rotate-0 group-data-shown:opacity-40"
            />
          </summary>
          <div data-answer class="relative overflow-hidden">
            <p class="max-w-[44em] px-4 pb-6 text-lg text-pale-blue md:px-6 md:text-xl">
              {@render faq.answer()}
            </p>
          </div>
        </details>
      {/each}
    </div>
  </div>
</section>
