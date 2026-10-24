<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import * as Alert from '@/components/admin/ui/alert'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import { formatDateTime, timeFromNow } from '@/lib/format'
  import { adminMcp, adminSqlChange } from '@/routes'
  import type { AdminSqlChangeDetail } from '@/types'

  let { change }: { change: AdminSqlChangeDetail } = $props()

  let deciding = $state(false)

  const verb = $derived({ insert: 'adds', update: 'changes', delete: 'deletes' }[change.kind] ?? 'changes')
  const keyIndex = $derived(change.key ? change.columns.indexOf(change.key) : -1)
  // An update shows only the columns that change; the rest are the same before and after.
  const changed = $derived(
    change.kind === 'update'
      ? change.columns
          .map((column, i) => ({ column, i }))
          .filter(({ i }) => change.rows.some((row) => row.before?.[i] !== row.after?.[i]))
      : [],
  )
  const shown = $derived(change.rows.length)

  // null and an empty string look alike as text, and an empty cell can't show it was struck out.
  const show = (value: string | null | undefined) => (value == null ? 'null' : value === '' ? '""' : value)

  function decide(decision: 'approve' | 'reject') {
    deciding = true
    router.patch(adminSqlChange(change.id), { decision }, { onFinish: () => (deciding = false) })
  }
</script>

<svelte:head><title>SQL change · Fallen Admin</title></svelte:head>

<Link
  href={adminMcp.index()}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" /> MCP
</Link>

<div class="mb-4 flex flex-wrap items-center gap-2">
  <h1 class="text-2xl font-semibold tracking-tight">
    This {verb}
    {change.count}
    {change.count === 1 ? 'row' : 'rows'} in <span class="font-mono">{change.table_name}</span>
  </h1>
  <Badge
    variant={change.state === 'pending' ? 'default' : change.state === 'done' ? 'secondary' : 'destructive'}
  >
    {change.state}
  </Badge>
</div>

<p class="mb-4 text-sm text-muted-foreground">
  Asked for by {change.requested_by.name}'s agent with the token “{change.token_name}”, {formatDateTime(
    change.created_at,
  )}.
  {#if change.state === 'pending'}
    Expires {timeFromNow(change.expires_at)}.
  {:else if change.reviewer}
    {change.state === 'rejected' ? 'Rejected' : 'Approved'} by {change.reviewer.name}{change.resolved_at
      ? `, ${formatDateTime(change.resolved_at)}`
      : ''}.
  {/if}
</p>

<pre
  class="mb-4 overflow-x-auto rounded-md bg-muted p-3 font-mono text-xs whitespace-pre-wrap">{change.sql}</pre>

{#if change.state === 'done'}
  <Alert.Root class="mb-4"><Alert.Title>Done. {change.rows_affected} rows changed.</Alert.Title></Alert.Root>
{:else if change.state === 'failed'}
  <Alert.Root variant="destructive" class="mb-4">
    <Alert.Title>Nothing was changed.</Alert.Title>
    <Alert.Description>{change.error}</Alert.Description>
  </Alert.Root>
{/if}

<div class="mb-2 text-sm text-muted-foreground">
  {#if shown < change.count}Showing the first {shown} of {change.count} rows.{/if}
  {#if change.kind === 'update' && changed.length === 0}It leaves these rows as they are.{/if}
</div>

<div class="mb-6 overflow-x-auto rounded-md border border-border">
  <table class="w-full text-xs">
    <thead class="bg-muted/50 text-left">
      <tr>
        {#if change.kind === 'update'}
          {#if keyIndex >= 0}<th class="px-3 py-2 font-medium">{change.key}</th>{/if}
          {#each changed as { column } (column)}<th class="px-3 py-2 font-medium">{column}</th>{/each}
        {:else}
          {#each change.columns as column (column)}<th class="px-3 py-2 font-medium">{column}</th>{/each}
        {/if}
      </tr>
    </thead>
    <tbody class="divide-y divide-border font-mono">
      {#each change.rows as row, r (r)}
        <tr
          class={change.kind === 'delete'
            ? 'bg-destructive/5'
            : change.kind === 'insert'
              ? 'bg-emerald-500/5'
              : ''}
        >
          {#if change.kind === 'update'}
            {#if keyIndex >= 0}<td class="px-3 py-2 align-top">{row.after?.[keyIndex]}</td>{/if}
            {#each changed as { column, i } (column)}
              <td class="px-3 py-2 align-top">
                {#if row.before?.[i] === row.after?.[i]}
                  <span class="text-muted-foreground">{show(row.after?.[i])}</span>
                {:else}
                  <div class="text-destructive line-through">{show(row.before?.[i])}</div>
                  <div class="text-emerald-600 dark:text-emerald-400">{show(row.after?.[i])}</div>
                {/if}
              </td>
            {/each}
          {:else}
            {#each (change.kind === 'delete' ? row.before : row.after) ?? [] as value, i (i)}
              <td class="max-w-xs truncate px-3 py-2 align-top" title={show(value)}>{show(value)}</td>
            {/each}
          {/if}
        </tr>
      {/each}
    </tbody>
  </table>
</div>

{#if change.state === 'pending'}
  <p class="mb-3 max-w-2xl text-sm text-muted-foreground">
    Raw SQL skips the app's validations, callbacks and change history. When you approve, it runs only if it
    touches exactly these rows and none of them changed since this preview; otherwise nothing is written.
  </p>
  <div class="flex gap-2">
    <Button onclick={() => decide('approve')} disabled={deciding}>Approve and run</Button>
    <Button variant="outline" onclick={() => decide('reject')} disabled={deciding}>Reject</Button>
  </div>
{/if}
