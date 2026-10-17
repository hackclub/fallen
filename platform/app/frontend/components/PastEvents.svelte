<script lang="ts">
  // Beside the landing page's intro: two cards dealt one over the other, the back one leaning right and the front one
  // left. The cards are blank until there are photos of past events, and their caption is hidden for now.
  //
  // A hand of cards after crescent.hackclub.com's: the card under the pointer lifts, straightens and grows while the
  // other slides aside, and it stays in front, the larger of the two, once the pointer leaves. Each card is hovered
  // through a still copy of its resting shape, so a card moving out from under the pointer never makes it flicker.
  //
  // Each corner is scooped out by a quarter circle, like the recap video's (RecapVideo.svelte), and the card's edge
  // and its inner hairline both follow the scoops, with a dot between them in each corner.

  const [width, height] = [216, 288] // px of each card
  const scoop = 14 // px radius of the corner notches, centred on the card's corners
  const edge = 2 // px of the tangerine edge
  const hairline = 8 // px from the card's edge in to the inner line

  // the card's outline inset by `inset`, its corners cut by circles of `radius` centred on the card's corners
  function notched(inset: number, radius: number) {
    const [a, w, h] = [Math.sqrt(radius ** 2 - inset ** 2), width, height]
    return [
      `M${a} ${inset}H${w - a}`,
      `A${radius} ${radius} 0 0 0 ${w - inset} ${a}V${h - a}`,
      `A${radius} ${radius} 0 0 0 ${w - a} ${h - inset}H${a}`,
      `A${radius} ${radius} 0 0 0 ${inset} ${h - a}V${a}`,
      `A${radius} ${radius} 0 0 0 ${a} ${inset}Z`,
    ].join('')
  }
  const mask = ['0 0', '100% 0', '0 100%', '100% 100%']
    .map(
      (at) =>
        `radial-gradient(${scoop}px at ${at}, #0000 calc(100% - 0.5px), #000) ${at} / 51% 51% no-repeat`,
    )
    .join(', ')
  // the dots, on each corner's diagonal halfway between the notch and the inner line's
  const dot = ((scoop + scoop + hairline) / 2) * Math.SQRT1_2
  const dots = [
    [dot, dot],
    [width - dot, dot],
    [dot, height - dot],
    [width - dot, height - dot],
  ]

  // where each card rests: px from the left, and its lean in degrees
  const hand = [
    { x: 0, lean: -12 },
    { x: 34, lean: 7 },
  ]
  let active = $state(0) // the card in front
  let hovered: number | null = $state(null)

  function place(i: number) {
    const lifted = hovered === i
    // the other card slides away from the lifted one
    const aside = hovered === null || lifted ? 0 : Math.sign(hand[i].x - hand[hovered].x) * 16
    const scale = (active === i ? 1 : 0.92) * (lifted ? 1.05 : 1)
    const lean = lifted ? hand[i].lean / 3 : hand[i].lean
    return `translate(${hand[i].x + aside}px, ${lifted ? -14 : 0}px) rotate(${lean}deg) scale(${scale})`
  }
</script>

<figure class="flex shrink-0 flex-col items-center gap-8">
  <div class="relative h-76 w-64" aria-hidden="true">
    {#each hand as _, i (i)}
      <!-- z-index moves with the card, so the two trade places halfway through rather than at the start. The shadow is
           on this wrapper because the notches' mask would cut it off -->
      <div
        class={[
          'pointer-events-none absolute top-2 left-0 transition-[transform,z-index,filter] duration-250 ease-out motion-reduce:transition-none',
          active === i
            ? 'drop-shadow-[0_18px_22px_rgb(12_18_56/0.55)]'
            : 'drop-shadow-[0_10px_14px_rgb(12_18_56/0.4)]',
        ]}
        style:width="{width}px"
        style:height="{height}px"
        style:transform={place(i)}
        style:z-index={active === i ? 2 : 1}
      >
        <svg class="size-full bg-mist" style:mask viewBox="0 0 {width} {height}" fill="none">
          <path d={notched(edge / 2, scoop + edge / 2)} class="stroke-tangerine" stroke-width={edge} />
          <path d={notched(hairline, scoop + hairline)} class="stroke-sand/70" stroke-width="1" />
          {#each dots as [x, y] (`${x},${y}`)}
            <circle cx={x} cy={y} r="2" class="fill-sand/80" />
          {/each}
        </svg>
      </div>
      <!-- the card's resting shape, which takes the pointer; the front card's is on top, like the card itself -->
      <div
        role="presentation"
        class="absolute top-2 left-0"
        style:width="{width}px"
        style:height="{height}px"
        style:transform="translate({hand[i].x}px, 0) rotate({hand[i].lean}deg)"
        style:z-index={active === i ? 4 : 3}
        onpointerenter={() => (hovered = active = i)}
        onpointerleave={() => (hovered = null)}
      ></div>
    {/each}
  </div>
  <!-- <figcaption
    class="mt-3 flex items-center gap-6 text-center text-lg leading-tight tracking-wide text-parchment"
  >
    <svg class="size-4 shrink-0 rotate-45" viewBox="0 0 29.1 29.1" aria-hidden="true"
      ><path d={starPath} fill="currentColor" /></svg
    >
    <span class="">Events we've run in the past</span>
    <svg class="size-4 shrink-0 rotate-45" viewBox="0 0 29.1 29.1" aria-hidden="true"
      ><path d={starPath} fill="currentColor" /></svg
    >
  </figcaption> -->
</figure>
