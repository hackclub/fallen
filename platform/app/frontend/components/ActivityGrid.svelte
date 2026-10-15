<script lang="ts">
  import { formatMinutes } from '@/lib/format'

  // One square per day, a column per week (Monday on top), like a contribution graph.
  let { days }: { days: { date: string; minutes: number }[] } = $props()

  const dayFormatter = new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })

  const parse = (iso: string) => {
    const [y, m, d] = iso.split('-').map(Number)
    return new Date(y, m - 1, d)
  }

  // Blank cells before the first day so it lands on its weekday row.
  const lead = $derived(days.length ? (parse(days[0].date).getDay() + 6) % 7 : 0)

  function level(minutes: number) {
    if (minutes <= 0) return 'bg-ink/10'
    if (minutes < 60) return 'bg-ink/30'
    if (minutes < 120) return 'bg-ink/50'
    if (minutes < 180) return 'bg-ink/75'
    return 'bg-ink'
  }
</script>

<div class="overflow-x-auto">
  <ol class="grid w-max grid-flow-col grid-rows-7 gap-1.5">
    {#each { length: lead }, i (i)}
      <li aria-hidden="true" class="h-5 w-5"></li>
    {/each}
    {#each days as day (day.date)}
      {@const label = `${dayFormatter.format(parse(day.date))}: ${day.minutes ? formatMinutes(day.minutes) : 'nothing logged'}`}
      <li title={label} aria-label={label} class="h-5 w-5 rounded-[4px] {level(day.minutes)}"></li>
    {/each}
  </ol>
</div>
