<script lang="ts">
  import type { AdminJob } from '@/types'

  let { job }: { job: AdminJob } = $props()
</script>

{#if job.error}
  <div class="max-w-[28rem] min-w-0" title={job.error.message}>
    <span class="block truncate font-mono text-xs font-medium text-destructive"
      >{job.error.exception_class}</span
    >
    <span class="line-clamp-2 text-xs text-muted-foreground">{job.error.message}</span>
  </div>
{/if}
