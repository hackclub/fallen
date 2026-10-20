<script lang="ts">
  import type { Snippet } from 'svelte'
  import NumberPopIn from '@/components/admin/NumberPopIn.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Skeleton } from '@/components/admin/ui/skeleton'

  // A number on a card. `value` undefined shows a skeleton while a deferred prop loads.
  let {
    label,
    value,
    hint,
    tone = 'default',
    icon,
  }: {
    label: string
    value: string | number | undefined
    hint?: string
    tone?: 'default' | 'bad' | 'warn' | 'good'
    icon?: Snippet
  } = $props()

  const toneClass = {
    default: '',
    bad: 'text-destructive',
    warn: 'text-amber-600 dark:text-amber-400',
    good: 'text-emerald-600 dark:text-emerald-400',
  }
</script>

<Card.Root class="h-full gap-2">
  <Card.Header>
    <Card.Description class="flex items-center justify-between gap-2">
      {label}
      {@render icon?.()}
    </Card.Description>
    <Card.Title class="text-2xl tabular-nums {toneClass[tone]}">
      {#if value === undefined}
        <Skeleton class="h-8 w-20" />
      {:else}
        <NumberPopIn {value} />
      {/if}
    </Card.Title>
    {#if hint}<p class="text-xs text-muted-foreground">{hint}</p>{/if}
  </Card.Header>
</Card.Root>
