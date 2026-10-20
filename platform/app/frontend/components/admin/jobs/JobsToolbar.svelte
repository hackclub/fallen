<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Check from '@lucide/svelte/icons/check'
  import ChevronDown from '@lucide/svelte/icons/chevron-down'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import RotateCcw from '@lucide/svelte/icons/rotate-ccw'
  import SearchIcon from '@lucide/svelte/icons/search'
  import Trash2 from '@lucide/svelte/icons/trash-2'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import * as DropdownMenu from '@/components/admin/ui/dropdown-menu'
  import * as InputGroup from '@/components/admin/ui/input-group'
  import { formatCount } from '@/lib/format'
  import { JOB_RELOAD, type JobStatus } from '@/lib/jobs'
  import { adminJobs, discardAllAdminJobs, retryAllAdminJobs } from '@/routes'

  // Search by job class and pick a queue, as partial reloads that keep the URL shareable. On the failed tab, the
  // bulk actions apply to exactly what the filters show.
  let {
    status,
    queue,
    query,
    queueNames,
    failedCount,
  }: { status: JobStatus; queue: string; query: string; queueNames: string[]; failedCount?: number } =
    $props()

  // svelte-ignore state_referenced_locally
  let search = $state(query)
  let searching = $state(false)
  let bulk = $state<'retry' | 'discard' | null>(null)
  let working = $state(false)
  let timer: ReturnType<typeof setTimeout> | undefined

  const filters = $derived({ ...(queue && { queue }), ...(query && { query }) })
  const filtered = $derived(Boolean(queue || query))

  function visit(next: { queue?: string; query?: string }) {
    clearTimeout(timer)
    const params: Record<string, string> = {}
    if (status !== 'failed') params.status = status
    const nextQueue = next.queue ?? queue
    const nextQuery = next.query ?? search
    if (nextQueue) params.queue = nextQueue
    if (nextQuery) params.query = nextQuery

    router.get(adminJobs.index().url, params, {
      preserveState: true,
      preserveScroll: true,
      replace: true,
      only: [...JOB_RELOAD, 'queue', 'query'],
      onStart: () => (searching = true),
      onFinish: () => (searching = false),
    })
  }

  function oninput() {
    clearTimeout(timer)
    timer = setTimeout(() => visit({}), 250)
  }

  function runBulk() {
    const route =
      bulk === 'retry' ? retryAllAdminJobs({ query: filters }) : discardAllAdminJobs({ query: filters })
    router.post(
      route,
      {},
      {
        preserveScroll: true,
        preserveState: true,
        only: JOB_RELOAD,
        onStart: () => (working = true),
        onFinish: () => {
          working = false
          bulk = null
        },
      },
    )
  }
</script>

<div class="mb-4 flex flex-wrap items-center gap-2">
  <form
    class="flex min-w-0 basis-full sm:basis-0 sm:flex-1"
    onsubmit={(event) => {
      event.preventDefault()
      visit({})
    }}
  >
    <InputGroup.Root class="flex-1 sm:max-w-sm">
      <InputGroup.Addon><SearchIcon /></InputGroup.Addon>
      <InputGroup.Input type="search" bind:value={search} {oninput} placeholder="Search job classes" />
      {#if searching}
        <InputGroup.Addon align="inline-end"
          ><LoaderCircle class="animate-spin text-muted-foreground" /></InputGroup.Addon
        >
      {/if}
    </InputGroup.Root>
  </form>

  <DropdownMenu.Root>
    <DropdownMenu.Trigger>
      {#snippet child({ props })}
        <Button {...props} variant="outline" size="sm" class={queue ? 'border-primary/50' : ''}>
          <span class="text-muted-foreground">Queue:</span>
          <span class="font-mono text-xs">{queue || 'all'}</span>
          <ChevronDown data-icon="inline-end" />
        </Button>
      {/snippet}
    </DropdownMenu.Trigger>
    <DropdownMenu.Content align="end" class="min-w-44">
      {#each ['', ...queueNames] as name (name)}
        <DropdownMenu.Item onSelect={() => visit({ queue: name })} class="font-mono text-xs">
          <Check class={name === queue ? 'opacity-100' : 'opacity-0'} />
          {name || 'All queues'}
        </DropdownMenu.Item>
      {/each}
    </DropdownMenu.Content>
  </DropdownMenu.Root>

  {#if status === 'failed' && failedCount}
    <div class="ml-auto flex items-center gap-2">
      <Button variant="outline" size="sm" onclick={() => (bulk = 'retry')}>
        <RotateCcw data-icon="inline-start" />
        Retry {filtered ? 'matching' : 'all'}
      </Button>
      <Button variant="outline" size="sm" class="hover:text-destructive" onclick={() => (bulk = 'discard')}>
        <Trash2 data-icon="inline-start" />
        Discard {filtered ? 'matching' : 'all'}
      </Button>
    </div>
  {/if}
</div>

<AlertDialog.Root open={bulk !== null} onOpenChange={(open) => !open && (bulk = null)}>
  <AlertDialog.Content>
    <AlertDialog.Header>
      <AlertDialog.Title>
        {bulk === 'retry' ? 'Retry' : 'Discard'}
        {filtered ? 'every failed job that matches' : `all ${formatCount(failedCount ?? 0)} failed jobs`}?
      </AlertDialog.Title>
      <AlertDialog.Description>
        {#if bulk === 'retry'}
          They go back to their queues with their attempts reset, and run again as workers get to them.
        {:else}
          They're deleted and won't run again. This can't be undone.
        {/if}
        {#if filtered}
          Matching {[queue && `queue ${queue}`, query && `“${query}”`].filter(Boolean).join(' and ')}.
        {/if}
      </AlertDialog.Description>
    </AlertDialog.Header>
    <AlertDialog.Footer>
      <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
      <AlertDialog.Action
        variant={bulk === 'discard' ? 'destructive' : 'default'}
        onclick={runBulk}
        disabled={working}
      >
        {bulk === 'retry' ? 'Retry them' : 'Discard them'}
      </AlertDialog.Action>
    </AlertDialog.Footer>
  </AlertDialog.Content>
</AlertDialog.Root>
