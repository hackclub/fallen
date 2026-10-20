<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router, useForm } from '@inertiajs/svelte'
  import ChevronRight from '@lucide/svelte/icons/chevron-right'
  import Flag from '@lucide/svelte/icons/flag'
  import Plus from '@lucide/svelte/icons/plus'
  import SearchIcon from '@lucide/svelte/icons/search'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import FlagState from '@/components/admin/flags/FlagState.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Dialog from '@/components/admin/ui/dialog'
  import { Input } from '@/components/admin/ui/input'
  import * as InputGroup from '@/components/admin/ui/input-group'
  import { Label } from '@/components/admin/ui/label'
  import { Switch } from '@/components/admin/ui/switch'
  import { flagUsage, type FlagGroups } from '@/lib/flags'
  import { adminFlag, adminFlags } from '@/routes'
  import type { AdminFlag } from '@/types'

  let { flags, groups }: { flags: AdminFlag[]; groups: FlagGroups } = $props()

  const KEY_FORMAT = /^[a-z][a-z0-9_]*$/

  let filter = $state('')
  let creating = $state(false)
  // The flag the confirmation is about, kept while it fades out after the list has changed.
  let switching = $state<AdminFlag | null>(null)
  let confirming = $state(false)
  const form = useForm({ key: '' })

  const visible = $derived.by(() => {
    const needle = filter.trim().toLowerCase()
    return needle ? flags.filter((flag) => flag.key.includes(needle) || flag.summary.includes(needle)) : flags
  })
  const counts = $derived({
    on: flags.filter((flag) => flag.state === 'on').length,
    conditional: flags.filter((flag) => flag.state === 'conditional').length,
  })
  // Typed keys become valid ones as they're typed: "New Shop" -> "new_shop".
  const typedKey = $derived(
    form.key
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, ''),
  )
  const keyProblem = $derived(
    typedKey && !KEY_FORMAT.test(typedKey)
      ? 'Start with a letter.'
      : flags.some((flag) => flag.key === typedKey)
        ? 'There is already a flag with this name.'
        : null,
  )

  function create(event: SubmitEvent) {
    event.preventDefault()
    if (!typedKey || keyProblem) return
    form
      .transform(() => ({ flag: { key: typedKey } }))
      .submit(adminFlags.create(), {
        onSuccess: () => {
          creating = false
          form.reset()
        },
      })
  }

  function setEveryone(flag: AdminFlag, everyone: boolean) {
    router.patch(
      adminFlags.update(flag.key),
      { flag: { everyone } },
      { preserveScroll: true, preserveState: true, only: ['flags'], onFinish: () => (confirming = false) },
    )
  }

  function groupLabels(flag: AdminFlag) {
    return flag.groups.map((group) => groups[group]?.label ?? group)
  }
</script>

<svelte:head><title>Flags · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="flex items-center gap-2 text-2xl font-semibold tracking-tight">
      Flags
      {#if flags.length}<Badge variant="secondary" class="text-sm">{flags.length}</Badge>{/if}
    </h1>
    <p class="text-sm text-muted-foreground">
      {#if flags.length}
        {counts.on} on for everyone, {counts.conditional} on for some people.
      {:else}
        Turn features on for some people before everyone.
      {/if}
    </p>
  </div>
  <Button size="sm" onclick={() => (creating = true)}><Plus data-icon="inline-start" /> New flag</Button>
</div>

{#if flags.length === 0}
  <EmptyState
    icon={Flag}
    title="No flags yet"
    description="Make one here, then check it in code. It starts off for everyone, so it's safe to ship first."
  >
    <code class="mt-2 rounded-md bg-muted px-2 py-1 font-mono text-xs">{flagUsage('new_shop')}</code>
    <Button size="sm" class="mt-3" onclick={() => (creating = true)}
      ><Plus data-icon="inline-start" /> New flag</Button
    >
  </EmptyState>
{:else}
  <InputGroup.Root class="mb-3 max-w-sm">
    <InputGroup.Addon><SearchIcon /></InputGroup.Addon>
    <InputGroup.Input type="search" bind:value={filter} placeholder="Filter flags" />
  </InputGroup.Root>

  <ul class="divide-y divide-border overflow-hidden rounded-md border border-border">
    {#each visible as flag, i (flag.key)}
      <li
        class="group t-row-enter relative flex items-center gap-4 px-4 py-3 transition-colors hover:bg-muted/50"
        style="animation-delay: {Math.min(i, 10) * 20}ms"
      >
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <Link
              href={adminFlag(flag.key)}
              class="truncate font-mono text-sm font-medium after:absolute after:inset-0"
            >
              {flag.key}
            </Link>
            <FlagState state={flag.state} />
          </div>
          <p class="mt-0.5 flex flex-wrap items-center gap-x-1.5 text-xs text-muted-foreground">
            {#if flag.state === 'conditional'}
              {#each groupLabels(flag) as label (label)}<Badge variant="secondary" class="text-[10px]"
                  >{label}</Badge
                >{/each}
              {#if flag.actors.length}
                <span class="flex -space-x-1.5">
                  {#each flag.actors.slice(0, 4) as actor (actor.id)}
                    {#if actor.avatar}
                      <img
                        src={actor.avatar}
                        alt={actor.name ?? actor.id}
                        title={actor.name ?? actor.id}
                        class="size-4 rounded-full bg-muted object-cover ring-2 ring-background"
                      />
                    {/if}
                  {/each}
                </span>
                {flag.actors.length === 1
                  ? (flag.actors[0].name ?? '1 person')
                  : `${flag.actors.length} people`}
              {/if}
              {#if flag.percentage_of_actors}<span>· {flag.percentage_of_actors}% of people</span>{/if}
              {#if flag.percentage_of_time}<span>· {flag.percentage_of_time}% of checks</span>{/if}
            {:else}
              {flag.state === 'on' ? 'Everyone has it.' : 'No one has it.'}
            {/if}
          </p>
        </div>
        <!-- Above the row's link, so switching doesn't open the flag. -->
        <div class="relative z-10 flex items-center gap-2">
          <Label for="everyone-{flag.key}" class="hidden text-xs font-normal text-muted-foreground sm:block">
            Everyone
          </Label>
          <Switch
            id="everyone-{flag.key}"
            bind:checked={
              () => flag.everyone,
              () => {
                switching = flag
                confirming = true
              }
            }
          />
        </div>
        <ChevronRight
          class="size-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100"
        />
      </li>
    {:else}
      <li class="px-4 py-10 text-center text-sm text-muted-foreground">No flags match “{filter}”.</li>
    {/each}
  </ul>
{/if}

<AlertDialog.Root bind:open={confirming}>
  <AlertDialog.Content>
    {#if switching}
      <AlertDialog.Header>
        <AlertDialog.Title>
          Turn <span class="font-mono">{switching.key}</span>
          {switching.everyone ? 'off for everyone' : 'on for everyone'}?
        </AlertDialog.Title>
        <AlertDialog.Description>
          {#if switching.everyone}
            No one will have it until you choose who does.
          {:else if switching.state === 'conditional'}
            Everyone gets it on their next page load, and its groups, people and shares are cleared.
          {:else}
            Everyone gets it on their next page load.
          {/if}
        </AlertDialog.Description>
      </AlertDialog.Header>
      <AlertDialog.Footer>
        <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
        <AlertDialog.Action
          variant={switching.everyone ? 'destructive' : 'default'}
          onclick={() => switching && setEveryone(switching, !switching.everyone)}
        >
          {switching.everyone ? 'Turn off' : 'Turn on'}
        </AlertDialog.Action>
      </AlertDialog.Footer>
    {/if}
  </AlertDialog.Content>
</AlertDialog.Root>

<Dialog.Root bind:open={creating}>
  <Dialog.Content class="sm:max-w-md">
    <form onsubmit={create} class="contents">
      <Dialog.Header>
        <Dialog.Title>New flag</Dialog.Title>
        <Dialog.Description
          >It starts off for everyone. Turn it on for people from its page.</Dialog.Description
        >
      </Dialog.Header>
      <div class="space-y-2">
        <Label for="flag-key">Name</Label>
        <!-- svelte-ignore a11y_autofocus -->
        <Input
          id="flag-key"
          bind:value={form.key}
          placeholder="new_shop"
          autocomplete="off"
          autofocus
          class="font-mono"
        />
        {#if keyProblem || form.errors.key}
          <p class="text-sm text-destructive">{keyProblem ?? form.errors.key}</p>
        {:else if typedKey}
          <p class="font-mono text-xs text-muted-foreground">{flagUsage(typedKey)}</p>
        {:else}
          <p class="text-xs text-muted-foreground">
            Lowercase, with underscores. Code checks it by this name.
          </p>
        {/if}
      </div>
      <Dialog.Footer>
        <Button type="button" variant="outline" onclick={() => (creating = false)}>Cancel</Button>
        <Button type="submit" disabled={!typedKey || !!keyProblem || form.processing}>Create flag</Button>
      </Dialog.Footer>
    </form>
  </Dialog.Content>
</Dialog.Root>
