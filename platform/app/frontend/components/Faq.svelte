<script lang="ts">
  // The landing page's FAQ: native <details>, so it works without JS, and the height animates where the browser
  // supports ::details-content and interpolate-size (elsewhere it just opens instantly).
  import DiamondOrnament from '@/components/DiamondOrnament.svelte'
  import PhotoCard from '@/components/PhotoCard.svelte'

  import type { ComponentProps, Snippet } from 'svelte'

  // shift is in % of the card's own size
  const leftPhotos: ComponentProps<typeof PhotoCard>[] = [
    { class: 'aspect-4/3 w-60', rotate: 5 },
    { class: 'aspect-4/3 w-70', rotate: -2 },
  ]
  const rightPhotos: ComponentProps<typeof PhotoCard>[] = [
    { class: 'aspect-6/5 w-40 z-30', rotate: 7, shift: [25, 0] },
    { class: 'aspect-4/3 w-70', rotate: -4, shift: [0, -25] },
    { class: 'aspect-4/3 w-80', rotate: 4, shift: [0, 33.33] },
  ]

  const faqs: { question: string; answer: Snippet }[] = [
    { question: 'Who can join?', answer: whoCanJoin },
    { question: 'Is this free/legit?', answer: isItLegit },
    { question: 'What do I build?', answer: whatToBuild },
    { question: "What if I can't go to Shenzhen?", answer: cantTravel },
    { question: "I've got more questions...", answer: moreQuestions },
  ]
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

{#snippet whatToBuild()}
  One large hardware project (think ~7 weeks of dedicated work!). Keep in mind you'll be demoing this project
  in Shenzhen!
{/snippet}

{#snippet cantTravel()}
  You can still take part level up your character to purchase 3D printers, CNC Mills - OR receive custom
  Fallen merchandise.
{/snippet}

{#snippet moreQuestions()}
  Ask in the {@render link('https://hackclub.enterprise.slack.com/archives/C0C9JQEPFL6', '#fallen-help')} on Slack
  and we'll be happy to help.
{/snippet}

<section
  id="faq"
  class="flex flex-col justify-center gap-10 overflow-clip px-6 py-20 text-pale-blue md:px-20"
>
  <h2
    class="mx-auto font-lora text-6xl font-bold text-green text-shadow-md text-shadow-dark-purple/40 md:text-7xl"
  >
    FAQ
  </h2>
  <div class="place-down-stage flex justify-center gap-10">
    <!--
    <div class="place-down z-20 hidden shrink-0 flex-col justify-center gap-40 xl:flex">
      {#each leftPhotos as photo, i (i)}
        <PhotoCard {...photo} />
      {/each}
    </div>
    -->
    <div class="place-down place-down-stage mx-auto max-w-215 min-w-0 flex-1 py-12 md:px-8">
      {#each faqs as faq, i (faq.question)}
        <details
          name="faq"
          open={i === 0}
          class="group place-down border-b-2 border-bright-blue/40 first-of-type:border-t-2 open:bg-linear-to-r open:from-transparent open:via-bright-blue/15 open:to-transparent open:first-of-type:border-t-transparent [&:has(+details[open])]:border-b-transparent
                    details-content:h-0 details-content:overflow-clip details-content:opacity-0
                    details-content:transition-[height,opacity,content-visibility] details-content:transition-discrete
                    details-content:duration-300 details-content:ease-out open:details-content:h-auto open:details-content:opacity-100"
        >
          <summary
            class="relative flex cursor-pointer list-none items-center gap-4 px-4 py-5 font-lora text-xl font-bold text-cream transition-colors duration-500 group-open:text-gold hover:text-gold [&::-webkit-details-marker]:hidden md:px-6 md:text-2xl"
          >
            {faq.question}
            <!-- In the summary, not the answer, so ::details-content's clip doesn't hide it. The panel behind is a gradient,
                    so nothing solid could fill the diamonds: instead the border line above an open item is hidden and redrawn
                    in two pieces that stop at the ornament, and the ornament is the border's colour at the same opacity. -->
            <span
              class="pointer-events-none absolute -top-0.5 right-[calc(50%+24px)] left-0 hidden h-0.5 bg-bright-blue/40 group-open:block"
              aria-hidden="true"
            ></span>
            <span
              class="pointer-events-none absolute -top-0.5 right-0 left-[calc(50%+24px)] hidden h-0.5 bg-bright-blue/40 group-open:block"
              aria-hidden="true"
            ></span>
            <DiamondOrnament
              class="pointer-events-none absolute -top-px left-1/2 z-10 hidden -translate-1/2 text-bright-blue opacity-40 group-open:block"
            />
          </summary>
          <p class="max-w-[44em] px-4 pb-6 text-lg text-pale-blue md:px-6 md:text-xl">
            {@render faq.answer()}
          </p>
        </details>
      {/each}
    </div>

    <!--
    <div class="place-down z-20 hidden shrink-0 flex-col justify-between pb-24 xl:flex">
      {#each rightPhotos as photo, i (i)}
        <PhotoCard {...photo} />
      {/each}
    </div>
    -->
  </div>
</section>
