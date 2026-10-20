<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import UserPlus from '@lucide/svelte/icons/user-plus'
  import { Button } from '@/components/admin/ui/button'
  import * as Command from '@/components/admin/ui/command'
  import * as Popover from '@/components/admin/ui/popover'
  import type { UserMatch } from '@/lib/flags'

  // Finds people by name, email or Slack ID through the page's optional `user_matches` prop, without leaving it.
  let {
    matches,
    exclude,
    onPick,
  }: { matches: UserMatch[] | undefined; exclude: string[]; onPick: (user: UserMatch) => void } = $props()

  let open = $state(false)
  let query = $state('')
  let loading = $state(false)
  let input = $state<HTMLInputElement | null>(null)
  let timer: ReturnType<typeof setTimeout> | undefined

  const results = $derived(query.trim() ? (matches ?? []).filter((user) => !exclude.includes(user.id)) : [])

  function search() {
    clearTimeout(timer)
    timer = setTimeout(() => {
      router.reload({
        only: ['user_matches'],
        data: { user_query: query.trim() },
        onStart: () => (loading = true),
        onFinish: () => (loading = false),
      })
    }, 200)
  }

  function pick(user: UserMatch) {
    onPick(user)
    open = false
    query = ''
  }
</script>

<Popover.Root bind:open>
  <Popover.Trigger>
    {#snippet child({ props })}
      <Button {...props} variant="outline" size="sm"
        ><UserPlus data-icon="inline-start" /> Add a person</Button
      >
    {/snippet}
  </Popover.Trigger>
  <Popover.Content
    class="w-80 p-0"
    align="end"
    onOpenAutoFocus={(event) => {
      event.preventDefault()
      input?.focus()
    }}
  >
    <Command.Root shouldFilter={false}>
      <div class="relative">
        <Command.Input
          bind:ref={input}
          placeholder="Name, email or Slack ID"
          bind:value={query}
          oninput={search}
        />
        {#if loading}
          <LoaderCircle
            class="absolute top-1/2 right-3 size-4 -translate-y-1/2 animate-spin text-muted-foreground"
          />
        {/if}
      </div>
      <Command.List>
        {#if query.trim() && !loading}
          <Command.Empty>No one found.</Command.Empty>
        {/if}
        {#each results as user (user.id)}
          <Command.Item value={user.id} onSelect={() => pick(user)} class="gap-2.5">
            <img src={user.avatar} alt="" class="size-6 shrink-0 rounded-full bg-muted object-cover" />
            <span class="min-w-0">
              <span class="block truncate text-sm">{user.name}</span>
              <span class="block truncate text-xs text-muted-foreground">{user.email}</span>
            </span>
          </Command.Item>
        {/each}
      </Command.List>
    </Command.Root>
  </Popover.Content>
</Popover.Root>
