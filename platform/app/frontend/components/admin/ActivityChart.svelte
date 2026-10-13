<script lang="ts">
  import { scaleUtc } from 'd3-scale'
  import { curveMonotoneX } from 'd3-shape'
  import { AreaChart } from 'layerchart'
  import * as Chart from '@/components/admin/ui/chart'

  // One series over days. `points` are { date: 'YYYY-MM-DD', value }.
  let {
    points,
    label,
    color,
    format = (value: number) => String(value),
  }: {
    points: { date: string; value: number }[]
    label: string
    color: string
    format?: (value: number) => string
  } = $props()

  const config = $derived({ value: { label, color } } satisfies Chart.ChartConfig)
  const data = $derived(
    points.map((point) => ({ date: new Date(`${point.date}T00:00:00`), value: point.value })),
  )
</script>

<Chart.Container {config} class="aspect-auto h-[220px] w-full">
  <AreaChart
    {data}
    x="date"
    xScale={scaleUtc()}
    series={[{ key: 'value', label, color }]}
    props={{
      area: { curve: curveMonotoneX, 'fill-opacity': 0.25, line: { class: 'stroke-2' } },
      xAxis: {
        format: (date: Date) => date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      },
      yAxis: { format: (value: number) => format(value) },
    }}
  >
    {#snippet tooltip()}
      <Chart.Tooltip
        labelFormatter={(date: Date) => date.toLocaleDateString(undefined, { month: 'long', day: 'numeric' })}
      >
        {#snippet formatter({ value })}
          <div class="flex w-full items-center justify-between gap-4">
            <span class="text-muted-foreground">{label}</span>
            <span class="font-mono font-medium tabular-nums">{format(Number(value))}</span>
          </div>
        {/snippet}
      </Chart.Tooltip>
    {/snippet}
  </AreaChart>
</Chart.Container>
