<script lang="ts">
  import { followPointer } from '@/lib/glimmer'

  // A stacked list of links with a line-and-diamonds ornament either side of the active one. The first link stays
  // active until another is hovered or focused, and again once the pointer leaves. small is the footer's size; glow
  // gives the links and ornaments a white glow, like the footer's wordmark. class goes on the nav, itemClass on each
  // link's row. A link with glimmer turns mint under the pointer, and the letters nearest it light up white. A link
  // with an avatar adds its `before` word, smaller, and the picture after its label. Both widen in once the picture
  // has loaded, since it usually arrives a few seconds after the page.
  let {
    items,
    small = false,
    glow = false,
    label,
    class: className = '',
    itemClass = '',
  }: {
    items: {
      label: string
      href: string
      onclick?: (event: MouseEvent) => void
      glimmer?: boolean
      avatar?: { src: string; alt: string; before?: string }
    }[]
    small?: boolean
    glow?: boolean
    label?: string
    class?: string
    itemClass?: string
  } = $props()

  const whiteGlow =
    '[filter:drop-shadow(0_0_6px_rgb(255_255_255/0.25))_drop-shadow(0_0_20px_rgb(255_255_255/0.1))]'

  let active = $state(0)

  // Pictures that have loaded, by src
  let loaded: Record<string, boolean> = $state({})
  const whenLoaded = (src: string) => (img: HTMLImageElement) => {
    const done = () => (loaded[src] = true)
    if (img.complete && img.naturalWidth) done()
    else img.addEventListener('load', done, { once: true })
  }
</script>

<!-- The label, drawn twice: for the link, and again as the glimmer's copy, which needs the same layout so the
     light lands on the same letters. The copy keeps the picture's space but not the picture. -->
{#snippet text(item: (typeof items)[number], copy: boolean)}
  <!-- flex, so the markup's whitespace adds no gaps -->
  <span class="inline-flex items-baseline">
    {item.label}
    {#if item.avatar}
      {@const shown = loaded[item.avatar.src]}
      <span
        class={[
          'grid transition-[grid-template-columns] duration-700 ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none',
          shown ? 'grid-cols-[1fr]' : 'grid-cols-[0fr]',
        ]}
      >
        <span class="min-w-0 overflow-clip [overflow-clip-margin:8px]">
          <span
            class={[
              'flex items-baseline gap-[0.2em] ps-[0.25em] transition-[opacity,translate] duration-500 motion-reduce:transition-none',
              shown ? 'opacity-100 delay-150' : '-translate-x-2 opacity-0',
            ]}
          >
            {#if item.avatar.before}<span class="text-[0.67em]">{item.avatar.before}</span>{/if}
            {#if copy}
              <span class="relative top-[0.2em] size-[1.1em] shrink-0"></span>
            {:else}
              <img
                {@attach whenLoaded(item.avatar.src)}
                src={item.avatar.src}
                alt={item.avatar.alt}
                class={[
                  'relative top-[0.2em] size-[1.1em] shrink-0 rounded-full ring-1 ring-parchment/70 transition-[scale] duration-700 ease-[cubic-bezier(0.3,1.6,0.5,1)] motion-reduce:transition-none',
                  shown ? 'scale-100 delay-200' : 'scale-50',
                ]}
                referrerpolicy="no-referrer"
              />
            {/if}
          </span>
        </span>
      </span>
    {/if}
  </span>
{/snippet}

{#snippet ornament(visible: boolean, extra = '')}
  <svg
    class={[
      'transition-opacity',
      glow ? whiteGlow : 'drop-shadow-[0_0_4px_rgb(255_255_255/0.6)]',
      // narrower on a phone, so the longest label and its ornaments still fit across the screen
      'max-sm:h-auto max-sm:w-12',
      extra,
      !visible && 'opacity-0',
    ]}
    aria-hidden="true"
    width={small ? 150 : 180}
    height={small ? 25 : 30}
    viewBox="0 0 202 43"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect
      x="0.821599"
      width="36.2118"
      height="36.2118"
      transform="matrix(0.821599 -0.570066 0.821599 0.570066 106.147 21.6816)"
      stroke="#FEFEFE"
      vector-effect="non-scaling-stroke"
    />
    <rect
      x="0.821599"
      width="36.2118"
      height="36.2118"
      transform="matrix(0.821599 -0.570066 0.821599 0.570066 122.002 21.6816)"
      stroke="#FEFEFE"
      vector-effect="non-scaling-stroke"
    />
    <!-- in two pieces that stop at the small diamond, which is hollow so the background shows through it -->
    <line y1="20.5" x2="71.5" y2="20.5" stroke="white" vector-effect="non-scaling-stroke" />
    <line x1="88.7" y1="20.5" x2="106" y2="20.5" stroke="white" vector-effect="non-scaling-stroke" />
    <line x1="182" y1="21" x2="202" y2="21" stroke="white" vector-effect="non-scaling-stroke" />
    <rect
      x="71.4923"
      y="21.2132"
      width="12.1802"
      height="12.1802"
      transform="rotate(-45 71.4923 21.2132)"
      fill="none"
      stroke="#FEFEFE"
      vector-effect="non-scaling-stroke"
    />
  </svg>
{/snippet}

<nav
  aria-label={label}
  class={[
    'relative z-10 flex flex-col items-center',
    small ? 'space-y-3' : 'space-y-1 sm:space-y-4',
    className,
  ]}
  onmouseleave={() => (active = 0)}
>
  {#each items as item, i (item.label)}
    {@const on = active === i}
    <div class={['flex items-center justify-center gap-2', itemClass]}>
      {@render ornament(on)}
      <a
        href={item.href}
        class={[
          'relative isolate font-lora whitespace-nowrap transition-all [paint-order:stroke_fill]',
          glow
            ? '[text-shadow:0_0_6px_rgb(255_255_255/0.18),0_0_20px_rgb(255_255_255/0.08)]'
            : 'text-shadow-md text-shadow-black/20',
          // the navy outline lifts the text off the hero's art, but would dim the glow
          !glow && (small ? '[-webkit-text-stroke:5px_#162C8640]' : '[-webkit-text-stroke:6px_#162C8640]'),
          on ? 'font-bold text-cream' : 'text-parchment',
          item.glimmer && 'group hover:text-mint',
          glow && !on && 'opacity-80',
          small
            ? on
              ? 'text-2xl sm:text-3xl'
              : 'text-xl sm:text-2xl'
            : on
              ? 'text-2xl sm:text-4xl'
              : 'text-xl sm:text-3xl',
        ]}
        onclick={item.onclick}
        onmouseenter={() => (active = i)}
        onpointermove={item.glimmer ? followPointer : undefined}
        onfocus={() => (active = i)}
      >
        <!-- the soft oval of light Genshin puts behind a selected menu item. It swells past its size and settles
             back as it lights up -->
        <span
          class={[
            'pointer-events-none absolute -inset-x-16 inset-y-1 -z-1 rounded-[50%] blur-md transition-[opacity,scale] duration-500 ease-[cubic-bezier(0.3,1.9,0.5,1)]',
            // it shows far more on the footer's near-black than on the hero's blue, so it's fainter there
            glow
              ? 'bg-[radial-gradient(closest-side,rgb(255_255_255/0.08),rgb(199_225_255/0.03)_55%,transparent)]'
              : 'bg-[radial-gradient(closest-side,rgb(255_255_255/0.3),rgb(199_225_255/0.12)_55%,transparent)]',
            on ? 'opacity-100' : 'scale-x-60 scale-y-50 opacity-0',
          ]}
          aria-hidden="true"
        ></span>
        {@render text(item, false)}
        {#if item.glimmer}
          <!-- the light, on a copy of the label without the outline, so only the letters catch it -->
          <span
            class="glimmer pointer-events-none absolute inset-0 opacity-0 group-hover:opacity-100"
            aria-hidden="true">{@render text(item, true)}</span
          >
        {/if}
      </a>
      {@render ornament(on, 'rotate-180')}
    </div>
  {/each}
</nav>
