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
    class: className = 'h-[220px]',
  }: {
    points: Point[]
    series: { key: string; label: string; color: string }[]
    kind?: 'area' | 'line'
    // Label the x axis with times of day rather than dates.
    hourly?: boolean
    format?: (value: number) => string
    class?: string
  } = $props()

  const config = $derived(
    Object.fromEntries(
      series.map((s) => [s.key, { label: s.label, color: s.color }]),
    ) satisfies Chart.ChartConfig,
  )
  const data = $derived(points.map((point) => ({ ...point, at: new Date(point.at) })))

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
    <AreaChart {data} x="at" xScale={scaleUtc()} {series} seriesLayout="overlap" props={chartProps}>
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
    <LineChart {data} x="at" xScale={scaleUtc()} {series} props={chartProps}>
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
