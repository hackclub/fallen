<script lang="ts">
  import { cubicOut } from 'svelte/easing'
  import { Tween, prefersReducedMotion } from 'svelte/motion'
  import { formatCount } from '@/lib/format'

  type Step = { key: string; label: string; count: number }

  // One centred shape, a band per step as wide as its share of the first step, curving in to the next step's width
  // at the bottom of the band. The percentage is of the step before; the biggest drop is marked.
  let { steps }: { steps: Step[] } = $props()

  const ROW = 40
  // How far down its band each step starts curving in.
  const FLAT = 16

  const start = $derived(steps[0]?.count ?? 0)
  // A sliver even at zero, so the shape doesn't vanish.
  const widths = Tween.of(() => steps.map((step) => Math.max(start ? (step.count / start) * 100 : 0, 0.5)), {
    duration: () => (prefersReducedMotion.current ? 0 : 500),
    easing: cubicOut,
  })
  const rates = $derived(
    steps.map((step, i) => (i === 0 ? 1 : steps[i - 1].count ? step.count / steps[i - 1].count : 1)),
  )
  const worst = $derived(
    rates.reduce(
      (worst, rate, i) => (i > 0 && rate < 1 && (worst < 0 || rate < rates[worst]) ? i : worst),
      -1,
    ),
  )
  const height = $derived(steps.length * ROW)

  function band(i: number) {
    const [width, next = width] = [widths.current[i], widths.current[i + 1]]
    const [top, turn, bottom] = [i * ROW, i * ROW + FLAT, (i + 1) * ROW]
    const middle = (turn + bottom) / 2
    const [l, r, nl, nr] = [50 - width / 2, 50 + width / 2, 50 - next / 2, 50 + next / 2]
    return `M${l},${top} H${r} V${turn} C${r},${middle} ${nr},${middle} ${nr},${bottom} H${nl} C${nl},${middle} ${l},${middle} ${l},${turn} Z`
  }
</script>

<div class="grid grid-cols-[minmax(0,14rem)_1fr_auto] gap-x-3 text-sm" style="grid-auto-rows: {ROW}px">
  <svg
    class="col-start-2 row-start-1 w-full"
    style="grid-row-end: span {steps.length}; height: {height}px"
    viewBox="0 0 100 {height}"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    {#each widths.current as _, i (i)}
      <path
        class="fill-chart-1 stroke-card"
        style="fill-opacity: {1 - (i / steps.length) * 0.5}"
        stroke-width="2"
        vector-effect="non-scaling-stroke"
        d={band(i)}
      />
    {/each}
  </svg>
  {#each steps as step, i (step.key)}
    <span
      class="col-start-1 flex items-center truncate text-muted-foreground"
      style="grid-row-start: {i + 1}"
      title={step.label}
    >
      {step.label}
    </span>
    <span
      class="col-start-3 flex w-28 items-center justify-end gap-1 tabular-nums"
      style="grid-row-start: {i + 1}"
    >
      <span class="font-medium">{formatCount(step.count)}</span>
      <span class={i === worst ? 'font-medium text-destructive' : 'text-muted-foreground'}>
        · {Math.round(rates[i] * 100)}%
      </span>
    </span>
  {/each}
</div>
