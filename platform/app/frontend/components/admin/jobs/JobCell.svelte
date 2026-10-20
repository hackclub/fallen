<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { adminJob } from '@/routes'
  import type { AdminJob } from '@/types'

  let { job }: { job: AdminJob } = $props()
</script>

<Link href={adminJob(job.id)} class="group block max-w-[26rem] min-w-0">
  <span class="block truncate font-mono text-xs font-medium group-hover:underline">{job.class_name}</span>
  <span class="block truncate font-mono text-[11px] text-muted-foreground" title={job.arguments}>
    {job.arguments || 'no arguments'}
  </span>
</Link>
