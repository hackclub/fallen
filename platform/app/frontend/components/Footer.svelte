<script lang="ts">
  import { starPath } from '@/components/GoldFrame.svelte'
  import OrnamentNav from '@/components/OrnamentNav.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { prefersReducedMotion } from 'svelte/motion'
  import type { ComponentProps } from 'svelte'

  let { nav }: { nav: ComponentProps<typeof OrnamentNav>['items'] } = $props()

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
  class="relative flex flex-col-reverse md:flex-row h-fit items-center justify-center gap-10 bg-navy/90 py-10 px-6 md:px-10 lg:px-16 pt-40 border-t-2 border-mint"
>
  <div class="absolute top-0 left-1/2 flex w-max -translate-1/2 items-center gap-6 text-mint">
    {@render star()}
    <!-- narrow, the banner shrinks so it and its stars fit the screen -->
    <div class="w-lg max-w-[min(20rem,calc(100vw-8rem))]">
      <svg width="100%" height="auto" viewBox="0 0 522 55" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M484.96 0L522 27.5L484.96 55H37.04L0 27.5L37.04 0H484.96Z" class="fill-mint" />
        <mask id="path-2-inside-1_695_699" fill="white">
          <path d="M474 0L511.04 27.5L474 55H51.04L14 27.5L51.04 0H474Z" />
        </mask>
        <path d="M474 0L511.04 27.5L474 55H51.04L14 27.5L51.04 0H474Z" class="fill-tangerine" />
        <path
          d="M474 0L475.192 -1.60581L474.661 -2H474V0ZM511.04 27.5L512.232 29.1058L514.395 27.5L512.232 25.8942L511.04 27.5ZM474 55V57H474.661L475.192 56.6058L474 55ZM51.04 55L49.8478 56.6058L50.3788 57H51.04V55ZM14 27.5L12.8078 25.8942L10.6449 27.5L12.8078 29.1058L14 27.5ZM51.04 0V-2H50.3788L49.8478 -1.60581L51.04 0ZM474 0L472.808 1.60581L509.848 29.1058L511.04 27.5L512.232 25.8942L475.192 -1.60581L474 0ZM511.04 27.5L509.848 25.8942L472.808 53.3942L474 55L475.192 56.6058L512.232 29.1058L511.04 27.5ZM474 55V53H51.04V55V57H474V55ZM51.04 55L52.2323 53.3942L15.1922 25.8942L14 27.5L12.8078 29.1058L49.8478 56.6058L51.04 55ZM14 27.5L15.1922 29.1058L52.2323 1.60581L51.04 0L49.8478 -1.60581L12.8078 25.8942L14 27.5ZM51.04 0V2H474V0V-2H51.04V0Z"
          class="fill-tangerine"
          mask="url(#path-2-inside-1_695_699)"
        />
      </svg>
    </div>
    {@render star()}
  </div>

  <div class="flex flex-col justify-end w-full mt-auto gap-8">
    <ul class="gap-8 font-lora text-2xl text-periwinkle">
      <li>
        <a class="transition-colors hover:text-cream" href="https://slack.hackclub.com">Join our Slack</a>
      </li>
      <li>
        <a class="transition-colors hover:text-cream" href="https://hackclub.com/privacy-and-terms"
          >Privacy Policy</a
        >
      </li>
      <li>
        <a class="transition-colors hover:text-cream" href="https://forms.hackclub.com/bounty"
          >Fulfilment Bounty</a
        >
      </li>
    </ul>
    <div class="flex flex-wrap items-center gap-x-12 gap-y-4 font-lora text-2xl text-mint italic">
      <a href="#watch" class="flex items-center gap-4 whitespace-nowrap transition-colors hover:text-cream">
        <span class="flex size-10 items-center justify-center rounded-full bg-indigo p-2.5">
          <svg
            aria-hidden="true"
            width="100%"
            height="100%"
            viewBox="0 0 27 28"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M2.6704 26.884C2.1904 26.884 1.8064 26.776 1.5184 26.56C1.2304 26.344 1.0624 26.056 1.0144 25.696C0.9664 25.336 1.0384 24.928 1.2304 24.472L10.9864 2.584C11.2264 2.008 11.5264 1.6 11.8864 1.36C12.2704 1.12 12.6904 1 13.1464 1C13.5784 1 13.9744 1.12 14.3344 1.36C14.7184 1.6 15.0304 2.008 15.2704 2.584L25.0264 24.472C25.2424 24.928 25.3264 25.348 25.2784 25.732C25.2304 26.092 25.0744 26.38 24.8104 26.596C24.5464 26.788 24.1744 26.884 23.6944 26.884C23.1664 26.884 22.7464 26.752 22.4344 26.488C22.1224 26.224 21.8464 25.816 21.6064 25.264L19.0864 19.432L20.7784 20.44H5.4424L7.0984 19.432L4.6144 25.264C4.3744 25.84 4.1104 26.26 3.8224 26.524C3.5344 26.764 3.1504 26.884 2.6704 26.884ZM13.0744 5.392L7.6384 18.28L6.7384 17.416H19.4464L18.6184 18.28L13.1464 5.392H13.0744Z"
              class="fill-mist"
              fill-opacity="0.8"
            />
            <path
              d="M13.1465 0.5C13.6725 0.500016 14.1598 0.648161 14.5986 0.9375L14.5996 0.935547C15.0964 1.24604 15.4627 1.74947 15.7275 2.38086L25.4785 24.2578L25.5635 24.4512C25.7485 24.9029 25.8294 25.3536 25.7744 25.7939V25.7979C25.7108 26.2747 25.496 26.6815 25.127 26.9834L25.1162 26.9922L25.1045 27C24.7233 27.2772 24.2326 27.3838 23.6943 27.3838C23.0834 27.3838 22.5372 27.2304 22.1113 26.8701C21.7197 26.5387 21.4047 26.0546 21.1475 25.4629V25.4619L19.1934 20.9404H6.99902L5.0752 25.4551L5.07617 25.4561C4.82306 26.0635 4.52425 26.5588 4.16016 26.8926L4.14258 26.9082C3.74199 27.242 3.23342 27.3838 2.66992 27.3838C2.11783 27.3837 1.61798 27.2593 1.21875 26.96C0.8223 26.6626 0.584118 26.2534 0.518555 25.7617C0.455393 25.2873 0.555159 24.7876 0.769531 24.2783L0.773438 24.2686L10.5293 2.38086C10.7908 1.75714 11.1411 1.25653 11.6094 0.944336L11.6152 0.939453L11.6211 0.935547C12.0851 0.645514 12.5975 0.5 13.1465 0.5ZM8.75586 16.916H17.4961L13.1113 6.58887L8.75586 16.916Z"
              class="stroke-mist"
              stroke-opacity="0.8"
            />
          </svg>
        </span>
        Play
      </a>
      <button
        type="button"
        class="flex cursor-pointer items-center gap-4 whitespace-nowrap transition-colors hover:text-cream"
        onclick={toTop}
      >
        <span class="flex size-10 items-center justify-center rounded-full bg-indigo p-2.5">
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
              class="stroke-mist"
              stroke-opacity="0.6"
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
    class="w-full md:w-200 h-fit mt-auto min-w-64 [filter:drop-shadow(0_0_6px_color-mix(in_srgb,var(--color-periwinkle)_45%,transparent))_drop-shadow(0_0_28px_color-mix(in_srgb,var(--color-periwinkle)_30%,transparent))]"
    fill="bg-periwinkle"
  />
</footer>
