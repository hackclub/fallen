<script lang="ts">
  import Link from '@/components/Link.svelte'
  import { reviewSubmission } from '@/routes'
  import type { ReviewQueueRow } from '@/types'

  let { row }: { row: ReviewQueueRow } = $props()
</script>

<Link href={reviewSubmission(row.id)} class="group flex items-center gap-2">
  <span class="font-medium group-hover:underline">{row.project_title}</span>
  {#if row.resubmission}
    <span
      class="rounded bg-sky-100 px-1.5 py-0.5 text-[10px] font-medium text-sky-700 dark:bg-sky-950 dark:text-sky-300"
      >Resubmitted</span
    >
  {/if}
  {#if row.sent_back_by}
    <span
      class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-800 dark:bg-amber-950 dark:text-amber-300"
      >Sent back by {row.sent_back_by.name}</span
    >
  {/if}
  {#if row.flagged}
    <span
      class="rounded bg-red-100 px-1.5 py-0.5 text-[10px] font-medium text-red-700 dark:bg-red-950 dark:text-red-400"
      >Flagged</span
    >
  {/if}
</Link>
