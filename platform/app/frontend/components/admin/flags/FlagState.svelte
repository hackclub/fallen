<script lang="ts">
  import { Badge } from '@/components/admin/ui/badge'
  import type { AdminFlag } from '@/types'

  let { state }: { state: AdminFlag['state'] } = $props()

  const look = {
    on: {
      label: 'On',
      class: 'border-emerald-500/40 bg-emerald-500/10 text-emerald-700 dark:text-emerald-400',
    },
    conditional: {
      label: 'Partly on',
      class: 'border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-400',
    },
    off: { label: 'Off', class: 'text-muted-foreground' },
  }
</script>

<Badge variant="outline" class="gap-1.5 {look[state].class}">
  <span
    class="size-1.5 rounded-full {state === 'on'
      ? 'bg-emerald-500'
      : state === 'conditional'
        ? 'bg-amber-500'
        : 'bg-muted-foreground/50'}"
  ></span>
  {look[state].label}
</Badge>
