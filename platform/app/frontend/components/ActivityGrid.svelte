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
    if (minutes <= 0) return 'bg-white/10'
    if (minutes < 60) return 'bg-cream/30'
    if (minutes < 120) return 'bg-cream/55'
    if (minutes < 180) return 'bg-cream/80'
    return 'bg-cream shadow-[0_0_8px_rgb(252_249_239/0.5)]'
  }
</script>

<div class="overflow-x-auto">
  <ol class="grid w-max grid-flow-col grid-rows-7 gap-1.5">
    {#each { length: lead }, i (i)}
      <li aria-hidden="true" class="h-4 w-4 md:h-5 md:w-5"></li>
    {/each}
    {#each days as day (day.date)}
      {@const label = `${dayFormatter.format(parse(day.date))}: ${day.minutes ? formatMinutes(day.minutes) : 'nothing logged'}`}
      <li
        title={label}
        aria-label={label}
        class="h-4 w-4 rounded-[3px] md:h-5 md:w-5 {level(day.minutes)}"
      ></li>
    {/each}
  </ol>
</div>
