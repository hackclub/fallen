<script lang="ts" module>
  // the four-point star in each corner, 29.1 units square; the Past projects line starts with it too
  export const starPath =
    'M26.2532 28.9079C27.9401 29.6836 29.6815 27.9421 28.9059 26.2553L23.9073 15.3845C23.6634 14.8541 23.6634 14.2437 23.9073 13.7134L28.9059 2.84258C29.6815 1.15574 27.9401 -0.5857 26.2532 0.189941L15.3824 5.18854C14.8521 5.4324 14.2417 5.4324 13.7113 5.18854L2.84052 0.18994C1.15368 -0.585701 -0.587765 1.15575 0.187876 2.84259L5.18648 13.7134C5.43034 14.2437 5.43034 14.8541 5.18648 15.3845L0.187874 26.2553C-0.587766 27.9421 1.15368 29.6836 2.84052 28.9079L13.7113 23.9093C14.2417 23.6655 14.8521 23.6655 15.3824 23.9093L26.2532 28.9079Z'
</script>

<script lang="ts">
  // The frame round the landing hero, drawn to the design's proportions in px from the hero's edges: a gold
  // hairline with rounded corners, a heavier line further in with a quarter-circle notch cut into each corner, and
  // in each corner a four-point star with two lines crossing through it on the diagonals, running off the edges.
  // An SVG sized to the frame, so every inset stays exact at any screen size. Goes inside a positioned element;
  // m-0 so a parent's space-y can't shift it.
  // the whole frame at half the design's size; the strokes stay as they are
  const size = 0.5
  const outerInset = 14 * size
  const outerRadius = 8 * size
  const innerInset = 41.5 * size
  // the corner pieces, at the design's proportions scaled down; the lines' insets stay as drawn
  const corner = 0.35
  const notch = 74 * corner * size // radius of the inner line's corner notches, centred on its corners
  // the star's centre, from both edges: halfway along the diagonal between the outer line's rounded corner and the
  // inner line's notch, so it sits in the middle of the gap between them
  const star = (outerInset + outerRadius * (1 - Math.SQRT1_2) + innerInset + notch * Math.SQRT1_2) / 2
  const cross = 30 * size // how far each crossing line runs from the star's centre, along each axis: past its points

  let width = $state(0)
  let height = $state(0)

  // the inner line: a rectangle whose corners are scooped out by circles centred on them
  const inner = $derived.by(() => {
    const [l, t, r, b, n] = [innerInset, innerInset, width - innerInset, height - innerInset, notch]
    return [
      `M${l + n} ${t}H${r - n}`,
      `A${n} ${n} 0 0 0 ${r} ${t + n}V${b - n}`,
      `A${n} ${n} 0 0 0 ${r - n} ${b}H${l + n}`,
      `A${n} ${n} 0 0 0 ${l} ${b - n}V${t + n}`,
      `A${n} ${n} 0 0 0 ${l + n} ${t}Z`,
    ].join('')
  })

  // the two lines crossing through a star at (x, y)
  const diagonals = (x: number, y: number) =>
    `M${x - cross} ${y - cross}L${x + cross} ${y + cross}M${x + cross} ${y - cross}L${x - cross} ${y + cross}`

  // each corner's star centre
  const corners = $derived([
    [star, star],
    [width - star, star],
    [star, height - star],
    [width - star, height - star],
  ])
</script>

<div
  class="pointer-events-none absolute inset-0 z-3 m-0"
  bind:clientWidth={width}
  bind:clientHeight={height}
  aria-hidden="true"
>
  {#if width}
    <svg class="absolute inset-0 size-full" viewBox="0 0 {width} {height}" fill="none">
      <g stroke="#EEB256">
        <rect
          x={outerInset}
          y={outerInset}
          width={width - outerInset * 2}
          height={height - outerInset * 2}
          rx={outerRadius}
          stroke-width="0.5"
        />
        <path d={inner} stroke-width="1" />
        {#each corners as [x, y] (`${x},${y}`)}
          <path d={diagonals(x, y)} stroke-width="1" />
        {/each}
      </g>
      <!-- the star, from its own 30px drawing centred on (14.55, 14.55): points on the diagonals, where the crossing
           lines run on out of them -->
      {#each corners as [x, y] (`${x},${y}`)}
        <path
          transform="translate({x - 14.55 * size} {y - 14.55 * size}) scale({size})"
          d={starPath}
          class="fill-saffron"
        />
      {/each}
    </svg>
  {/if}
</div>
