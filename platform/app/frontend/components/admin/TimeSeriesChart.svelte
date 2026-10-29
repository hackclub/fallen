<script lang="ts">
  import { scaleUtc } from 'd3-scale'
  import { curveMonotoneX } from 'd3-shape'
  import { AreaChart, LineChart } from 'layerchart'
  import * as Chart from '@/components/admin/ui/chart'

  type Point = { at: string } & Record<string, number | string | null>

  // Several series over time. `points` come one per bucket with an ISO `at`; a null value is a gap.
  let {
    points,
    series,
    kind = 'area',
    hourly = false,
    format = (value: number) => String(value),
    yAxis = true,
    class: className = 'h-[220px]',
  }: {
    points: Point[]
    series: { key: string; label: string; color: string }[]
    kind?: 'area' | 'line'
    // Label the x axis with times of day rather than dates.
    hourly?: boolean
    format?: (value: number) => string
    // Without the y axis's labels the plot runs edge to edge, lined up with what sits above it; hovering still
    // shows the numbers.
    yAxis?: boolean
    class?: string
  } = $props()

  const config = $derived(
    Object.fromEntries(
      series.map((s) => [s.key, { label: s.label, color: s.color }]),
    ) satisfies Chart.ChartConfig,
  )
  // Kept as is when a poll brings back the same points, so the chart doesn't redraw under the cursor.
  let data = $state.raw<Record<string, unknown>[]>([])
  let drawn = ''
  $effect.pre(() => {
    const next = JSON.stringify(points)
    if (next === drawn) return
    drawn = next
    data = points.map((point) => ({ ...point, at: new Date(point.at) }))
  })
  // The dots go straight to the point under the cursor rather than springing there.
  const highlight = { lines: true, points: true, motion: 'none' } as const
  const axis = $derived(yAxis ? true : 'x')
  const padding = $derived(yAxis ? undefined : { top: 4, left: 0, right: 0, bottom: 20 })

  const axisFormat = $derived(
    hourly
      ? (date: Date) => date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
      : (date: Date) => date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
  )
  const labelFormat = (date: Date) =>
    date.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
  const chartProps = $derived({
    xAxis: { format: axisFormat, ticks: 6 },
    yAxis: { format: (value: number) => format(value), ticks: 4 },
    area: { curve: curveMonotoneX, 'fill-opacity': 0.2, line: { class: 'stroke-[1.5]' } },
    spline: { curve: curveMonotoneX, class: 'stroke-[1.5]' },
  })
</script>

<Chart.Container {config} class="aspect-auto w-full {className}">
  {#if kind === 'area'}
    <AreaChart
      {data}
      x="at"
      xScale={scaleUtc()}
      {series}
      seriesLayout="overlap"
      {axis}
      {padding}
      {highlight}
      props={chartProps}
    >
      {#snippet tooltip()}
        <Chart.Tooltip labelFormatter={labelFormat} indicator="line">
          {#snippet formatter({ value, name, item })}
            <div class="flex w-full items-center justify-between gap-4">
              <span class="flex items-center gap-1.5 text-muted-foreground">
                <span class="size-2 rounded-[2px]" style="background: {item.color}"></span>{name}
              </span>
              <span class="font-mono font-medium tabular-nums">{format(Number(value))}</span>
            </div>
          {/snippet}
        </Chart.Tooltip>
      {/snippet}
    </AreaChart>
  {:else}
    <LineChart {data} x="at" xScale={scaleUtc()} {series} {axis} {padding} {highlight} props={chartProps}>
      {#snippet tooltip()}
        <Chart.Tooltip labelFormatter={labelFormat} indicator="line">
          {#snippet formatter({ value, name, item })}
            <div class="flex w-full items-center justify-between gap-4">
              <span class="flex items-center gap-1.5 text-muted-foreground">
                <span class="size-2 rounded-[2px]" style="background: {item.color}"></span>{name}
              </span>
              <span class="font-mono font-medium tabular-nums">
                {value == null ? '—' : format(Number(value))}
              </span>
            </div>
          {/snippet}
        </Chart.Tooltip>
      {/snippet}
    </LineChart>
  {/if}
</Chart.Container>
