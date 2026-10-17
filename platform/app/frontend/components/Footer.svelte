<script lang="ts">
  import { starPath } from '@/components/GoldFrame.svelte'
  import OrnamentNav from '@/components/OrnamentNav.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { followPointer } from '@/lib/glimmer'
  import { prefersReducedMotion } from 'svelte/motion'
  import type { ComponentProps } from 'svelte'

  let { nav }: { nav: ComponentProps<typeof OrnamentNav>['items'] } = $props()

  const bigStar =
    'M62.55 16.44L68.17 36.5Q70.87 46.13 80.5 48.83L100.56 54.45Q115 58.5 100.56 62.55L80.5 68.17Q70.87 70.87 68.17 80.5L62.55 100.56Q58.5 115 54.45 100.56L48.83 80.5Q46.13 70.87 36.5 68.17L16.44 62.55Q2 58.5 16.44 54.45L36.5 48.83Q46.13 46.13 48.83 36.5L54.45 16.44Q58.5 2 62.55 16.44Z'

  const links = [
    { label: 'Join our Slack', href: 'https://slack.hackclub.com' },
    { label: 'Privacy Policy', href: 'https://hackclub.com/privacy-and-terms' },
    { label: 'Fulfilment Bounty', href: 'https://forms.hackclub.com/bounty' },
  ]

  const toTop = () =>
    window.scrollTo({ top: 0, behavior: prefersReducedMotion.current ? 'instant' : 'smooth' })
</script>

{#snippet star()}
  <svg
    class="h-auto w-8 shrink-0 rotate-45 -translate-y-px"
    viewBox="-15.45 -15.45 60 60"
    fill="none"
    aria-hidden="true"
  >
    <path
      d="M-15.45 -15.45L44.55 44.55M44.55 -15.45L-15.45 44.55"
      stroke="currentColor"
      stroke-width="1"
      vector-effect="non-scaling-stroke"
    />
    <path d={starPath} fill="currentColor" />
  </svg>
{/snippet}

<footer
  class="relative flex flex-col-reverse md:flex-row h-fit items-center justify-center gap-10 bg-linear-to-b from-dark-purple to-black py-10 px-6 md:px-10 lg:px-16 pt-32"
>
  <!-- the top border and its stars, hidden for now. To bring them back, add border-t-2 border-gold to the footer
  <div class="absolute top-0 left-1/2 flex w-max -translate-1/2 items-center gap-6 text-gold">
    {@render star()}
    a four-pointed star on the border, outlined in gold as thick as the border inside its edge: the stroke is twice
    that, kept to that width whatever the star's size, and clipped to the star so only its inner half shows
    <svg class="size-18 shrink-0" viewBox="0 0 117 117" aria-hidden="true">
      <clipPath id="footer-star">
        <path d={bigStar} />
      </clipPath>
      <path
        d={bigStar}
        class="fill-blue stroke-gold"
        stroke-width="4"
        vector-effect="non-scaling-stroke"
        clip-path="url(#footer-star)"
      />
    </svg>
    {@render star()}
  </div>
  -->

  <div class="flex flex-col justify-end w-full mt-auto gap-8 mb-6">
    <ul
      class="font-lora text-base md:text-xl lg:text-2xl text-periwinkle [text-shadow:0_0_4px_color-mix(in_srgb,var(--color-periwinkle)_45%,transparent),0_0_16px_color-mix(in_srgb,var(--color-periwinkle)_30%,transparent)] flex flex-wrap justify-center whitespace-nowrap gap-x-1.5 gap-y-1 md:flex-col"
    >
      {#each links as link, i (link.href)}
        <li class="flex items-center gap-1.5">
          {#if i > 0}<span class="size-1 rounded-full bg-gold md:hidden" aria-hidden="true"></span>{/if}
          <a
            class="group relative transition-colors hover:text-parchment"
            href={link.href}
            onpointermove={followPointer}
          >
            {link.label}
            <span
              class="glimmer pointer-events-none absolute inset-0 opacity-0 group-hover:opacity-100"
              aria-hidden="true">{link.label}</span
            >
          </a>
        </li>
      {/each}
    </ul>
    <div
      class="justify-center md:justify-start flex flex-wrap items-center gap-x-12 gap-y-4 font-lora text-xl lg:text-2xl text-mint italic"
    >
      <button
        type="button"
        class="flex cursor-pointer items-center gap-4 whitespace-nowrap transition-colors hover:text-cream"
        onclick={toTop}
      >
        <span
          class="flex size-8 md:size-10 items-center justify-center rounded-full border-2 border-gold bg-blue p-1.5 md:p-2"
        >
          <svg
            aria-hidden="true"
            width="100%"
            height="100%"
            viewBox="0 0 29 29"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M14.4583 26.4167V2.5M26.4167 14.4583L14.4583 2.5L2.5 14.4583"
              class="stroke-gold"
              stroke-width="5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </span>
        Back to Top
      </button>
    </div>
  </div>

  <Wordmark
    class="w-full md:w-200 h-fit mt-auto -mb-2 min-w-64 [filter:drop-shadow(0_0_6px_color-mix(in_srgb,var(--color-periwinkle)_45%,transparent))_drop-shadow(0_0_28px_color-mix(in_srgb,var(--color-periwinkle)_30%,transparent))]"
    fill="bg-periwinkle"
  />
</footer>
