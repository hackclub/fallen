<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import Check from '@lucide/svelte/icons/check'
  import Copy from '@lucide/svelte/icons/copy'
  import Trash2 from '@lucide/svelte/icons/trash-2'
  import X from '@lucide/svelte/icons/x'
  import FlagState from '@/components/admin/flags/FlagState.svelte'
  import UserPicker from '@/components/admin/flags/UserPicker.svelte'
  import * as Alert from '@/components/admin/ui/alert'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { Slider } from '@/components/admin/ui/slider'
  import { Switch } from '@/components/admin/ui/switch'
  import { flagUsage, type FlagGroups, type UserMatch } from '@/lib/flags'
  import { adminFlags } from '@/routes'
  import type { AdminFlag } from '@/types'

  let { flag, groups, user_matches }: { flag: AdminFlag; groups: FlagGroups; user_matches?: UserMatch[] } =
    $props()

  type Change = Partial<{
    everyone: boolean
    groups: string[]
    actors: string[]
    percentage_of_actors: number
    percentage_of_time: number
  }>

  let saving = $state(false)
  let confirmEveryone = $state(false)
  // What the open confirmation is for, kept while it fades out after the flag has changed.
  let turningOn = $state(false)
  let wasConditional = $state(false)
  let confirmDelete = $state(false)
  let deleteTyped = $state('')
  let copied = $state(false)
  // svelte-ignore state_referenced_locally
  let percentage = $state(flag.percentage_of_actors)
  // svelte-ignore state_referenced_locally
  let timePercentage = $state(flag.percentage_of_time)
  // A change shows at once, and gives way to the flag as the server has it when the save comes back (or fails).
  let optimistic = $state<Change>({})
  let pending = $state<UserMatch[]>([])
  const shownGroups = $derived(optimistic.groups ?? flag.groups)

  $effect(() => {
    percentage = flag.percentage_of_actors
    timePercentage = flag.percentage_of_time
  })

  const actors = $derived([
    ...flag.actors,
    ...pending
      .filter((user) => !flag.actors.some((actor) => actor.id === user.id))
      .map((user) => ({
        id: user.id,
        name: user.name,
        avatar: user.avatar,
      })),
  ])

  function save(change: Change) {
    optimistic = change
    router.patch(
      adminFlags.update(flag.key),
      { flag: change },
      {
        preserveScroll: true,
        preserveState: true,
        only: ['flag'],
        onStart: () => (saving = true),
        onFinish: () => {
          saving = false
          pending = []
          optimistic = {}
        },
      },
    )
  }

  function toggleGroup(group: string, on: boolean) {
    save({ groups: on ? [...shownGroups, group] : shownGroups.filter((g) => g !== group) })
  }

  function addPerson(user: UserMatch) {
    pending = [...pending, user]
    save({ actors: [...flag.actors.map((actor) => actor.id), user.id] })
  }

  function removePerson(id: string) {
    save({ actors: flag.actors.map((actor) => actor.id).filter((actorId) => actorId !== id) })
  }

  async function copyUsage() {
    await navigator.clipboard.writeText(flagUsage(flag.key))
    copied = true
    setTimeout(() => (copied = false), 1500)
  }
</script>

<svelte:head><title>{flag.key} · Flags · Fallen Admin</title></svelte:head>

<Link
  href={adminFlags.index()}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" /> Flags
</Link>

<div class="flex flex-wrap items-center gap-3">
  <div class="min-w-0">
    <div class="flex items-center gap-2">
      <h1 class="truncate font-mono text-xl font-semibold tracking-tight">{flag.key}</h1>
      <FlagState state={flag.state} />
    </div>
    <p class="mt-0.5 text-sm text-muted-foreground first-letter:uppercase">{flag.summary}.</p>
  </div>
  <div class="ml-auto flex items-center gap-2">
    <button
      type="button"
      class="flex cursor-pointer items-center gap-2 rounded-md border border-border bg-muted/40 px-2.5 py-1 font-mono text-xs transition-colors hover:bg-muted"
      title="Copy"
      onclick={copyUsage}
    >
      {flagUsage(flag.key)}
      {#if copied}<Check class="size-3.5 text-emerald-600" />{:else}<Copy
          class="size-3.5 text-muted-foreground"
        />{/if}
    </button>
  </div>
</div>

{#if flag.expression}
  <Alert.Root class="mt-4">
    <Alert.Title>This flag also has an expression.</Alert.Title>
    <Alert.Description>Expressions can only be changed from a Rails console.</Alert.Description>
  </Alert.Root>
{/if}

<Card.Root class={['mt-6 transition-colors', flag.everyone && 'border-emerald-500/40 bg-emerald-500/5']}>
  <Card.Header>
    <Card.Title>Everyone</Card.Title>
    <Card.Description>
      {flag.everyone
        ? 'Everyone has it. Turn this off to choose who does instead.'
        : 'Off: only the groups, people and shares below have it.'}
    </Card.Description>
    <Card.Action>
      <!-- Controlled: it changes only once the confirmation is saved. -->
      <Switch
        bind:checked={
          () => flag.everyone,
          () => {
            turningOn = !flag.everyone
            wasConditional = flag.state === 'conditional'
            confirmEveryone = true
          }
        }
        disabled={saving}
      />
    </Card.Action>
  </Card.Header>
</Card.Root>

<!-- Flipper keeps no other rules while a flag is on for everyone, so they can't be set until it's off. -->
<fieldset
  disabled={flag.everyone}
  class={[
    'mt-4 grid min-w-0 gap-4 transition-opacity lg:grid-cols-2',
    flag.everyone && 'pointer-events-none opacity-50',
  ]}
>
  <Card.Root>
    <Card.Header>
      <Card.Title>Groups</Card.Title>
      <Card.Description>Turn it on for everyone in a group, as they are on each request.</Card.Description>
    </Card.Header>
    <Card.Content class="space-y-1">
      {#each Object.entries(groups) as [name, group] (name)}
        <Label
          for="group-{name}"
          class="flex cursor-pointer items-center justify-between gap-4 rounded-md px-2 py-2 font-normal hover:bg-muted/50"
        >
          <span>
            <span class="block text-sm font-medium">{group.label}</span>
            <span class="block text-xs text-muted-foreground">{group.description}</span>
          </span>
          <Switch
            id="group-{name}"
            bind:checked={() => shownGroups.includes(name), (on) => toggleGroup(name, on)}
            disabled={saving}
          />
        </Label>
      {/each}
    </Card.Content>
  </Card.Root>

  <Card.Root>
    <Card.Header>
      <Card.Title>People</Card.Title>
      <Card.Description>Turn it on for someone by name, to try it with them first.</Card.Description>
      <Card.Action>
        <UserPicker matches={user_matches} exclude={actors.map((actor) => actor.id)} onPick={addPerson} />
      </Card.Action>
    </Card.Header>
    <Card.Content>
      {#if actors.length}
        <ul class="divide-y divide-border">
          {#each actors as actor (actor.id)}
            <li class="t-row-enter flex items-center gap-2.5 py-2">
              {#if actor.avatar}
                <img src={actor.avatar} alt="" class="size-7 shrink-0 rounded-full bg-muted object-cover" />
              {:else}
                <span class="size-7 shrink-0 rounded-full bg-muted"></span>
              {/if}
              <span class="min-w-0 flex-1">
                <span class="block truncate text-sm">{actor.name ?? 'Unknown'}</span>
                <span class="block truncate font-mono text-[11px] text-muted-foreground">{actor.id}</span>
              </span>
              <Button
                variant="ghost"
                size="icon-sm"
                title="Remove"
                class="text-muted-foreground hover:text-destructive"
                disabled={saving}
                onclick={() => removePerson(actor.id)}
              >
                <X />
              </Button>
            </li>
          {/each}
        </ul>
      {:else}
        <p class="py-4 text-center text-sm text-muted-foreground">No one by name yet.</p>
      {/if}
    </Card.Content>
  </Card.Root>

  <Card.Root>
    <Card.Header>
      <Card.Title>A share of people</Card.Title>
      <Card.Description>
        The same people each time, so it doesn't flicker on and off for anyone. Raise it to roll out slowly.
      </Card.Description>
    </Card.Header>
    <Card.Content class="flex items-center gap-4">
      <Slider
        type="single"
        bind:value={percentage}
        max={100}
        step={1}
        disabled={saving}
        onValueCommit={(value) => save({ percentage_of_actors: value })}
        class="flex-1"
      />
      <div class="flex w-24 items-center gap-1">
        <Input
          type="number"
          min={0}
          max={100}
          bind:value={percentage}
          onchange={() => save({ percentage_of_actors: percentage })}
          class="h-8 text-right tabular-nums"
        />
        <span class="text-sm text-muted-foreground">%</span>
      </div>
    </Card.Content>
  </Card.Root>

  <Card.Root>
    <Card.Header>
      <Card.Title>A share of checks</Card.Title>
      <Card.Description>
        At random on each check, even for the same person. For load tests and gradual switches, not features
        people see.
      </Card.Description>
    </Card.Header>
    <Card.Content class="flex items-center gap-4">
      <Slider
        type="single"
        bind:value={timePercentage}
        max={100}
        step={1}
        disabled={saving}
        onValueCommit={(value) => save({ percentage_of_time: value })}
        class="flex-1"
      />
      <div class="flex w-24 items-center gap-1">
        <Input
          type="number"
          min={0}
          max={100}
          bind:value={timePercentage}
          onchange={() => save({ percentage_of_time: timePercentage })}
          class="h-8 text-right tabular-nums"
        />
        <span class="text-sm text-muted-foreground">%</span>
      </div>
    </Card.Content>
  </Card.Root>
</fieldset>

<Card.Root class="mt-8 border-destructive/30">
  <Card.Header>
    <Card.Title>Delete this flag</Card.Title>
    <Card.Description>
      Code that still checks it will see it as off. Remove those checks first.
    </Card.Description>
    <Card.Action>
      <Button
        variant="outline"
        size="sm"
        class="hover:text-destructive"
        onclick={() => (confirmDelete = true)}
      >
        <Trash2 data-icon="inline-start" /> Delete
      </Button>
    </Card.Action>
  </Card.Header>
</Card.Root>

<AlertDialog.Root bind:open={confirmEveryone}>
  <AlertDialog.Content>
    <AlertDialog.Header>
      <AlertDialog.Title>
        Turn <span class="font-mono">{flag.key}</span>
        {turningOn ? 'on' : 'off'} for everyone?
      </AlertDialog.Title>
      <AlertDialog.Description>
        {!turningOn
          ? 'No one will have it until you choose who does.'
          : wasConditional
            ? 'Everyone gets it on their next page load, and its groups, people and shares are cleared.'
            : 'Everyone gets it on their next page load.'}
      </AlertDialog.Description>
    </AlertDialog.Header>
    <AlertDialog.Footer>
      <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
      <AlertDialog.Action
        variant={turningOn ? 'default' : 'destructive'}
        onclick={() => {
          confirmEveryone = false
          save({ everyone: turningOn })
        }}
      >
        {turningOn ? 'Turn on' : 'Turn off'}
      </AlertDialog.Action>
    </AlertDialog.Footer>
  </AlertDialog.Content>
</AlertDialog.Root>

<AlertDialog.Root bind:open={confirmDelete} onOpenChange={() => (deleteTyped = '')}>
  <AlertDialog.Content>
    <AlertDialog.Header>
      <AlertDialog.Title>Delete <span class="font-mono">{flag.key}</span>?</AlertDialog.Title>
      <AlertDialog.Description>
        Its rules are deleted with it. Type its name to confirm.
      </AlertDialog.Description>
    </AlertDialog.Header>
    <Input bind:value={deleteTyped} placeholder={flag.key} class="font-mono" autocomplete="off" />
    <AlertDialog.Footer>
      <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
      <AlertDialog.Action
        variant="destructive"
        disabled={deleteTyped !== flag.key}
        onclick={() => router.delete(adminFlags.destroy(flag.key))}
      >
        Delete flag
      </AlertDialog.Action>
    </AlertDialog.Footer>
  </AlertDialog.Content>
</AlertDialog.Root>
