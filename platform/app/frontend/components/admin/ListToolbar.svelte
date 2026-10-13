<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import SearchIcon from '@lucide/svelte/icons/search'
  import SlidersHorizontal from '@lucide/svelte/icons/sliders-horizontal'
  import { Button } from '@/components/admin/ui/button'
  import * as DropdownMenu from '@/components/admin/ui/dropdown-menu'
  import * as InputGroup from '@/components/admin/ui/input-group'

  // Live search and filters for an admin list. Each change is a partial reload of `reload` only,
  // so the page keeps its state and the URL stays shareable.
  let {
    url,
    query,
    includeDeleted,
    reload,
    placeholder,
    deletedLabel,
  }: {
    url: string
    query: string
    includeDeleted: boolean
    reload: string[]
    placeholder: string
    deletedLabel: string
  } = $props()

  // svelte-ignore state_referenced_locally
  let search = $state(query)
  // svelte-ignore state_referenced_locally
  let deleted = $state(includeDeleted)
  let searching = $state(false)
  let timer: ReturnType<typeof setTimeout> | undefined

  function visit() {
    clearTimeout(timer)
    const params: Record<string, string> = {}
    if (search) params.query = search
    if (deleted) params.include_deleted = '1'

    router.get(url, params, {
      preserveState: true,
      preserveScroll: true,
      replace: true,
      only: [...reload, 'query', 'include_deleted', 'total_count', 'pagy'],
      onStart: () => (searching = true),
      onFinish: () => (searching = false),
    })
  }

  function oninput() {
    clearTimeout(timer)
    timer = setTimeout(visit, 250)
  }

  function onsubmit(event: SubmitEvent) {
    event.preventDefault()
    visit()
  }
</script>

<div class="mb-4 flex flex-wrap items-center gap-2">
  <form {onsubmit} class="flex min-w-0 flex-1">
    <InputGroup.Root class="max-w-md flex-1">
      <InputGroup.Addon><SearchIcon /></InputGroup.Addon>
      <InputGroup.Input type="search" bind:value={search} {oninput} {placeholder} />
      {#if searching}
        <InputGroup.Addon align="inline-end">
          <LoaderCircle class="animate-spin text-muted-foreground" />
        </InputGroup.Addon>
      {/if}
    </InputGroup.Root>
  </form>

  <div class="ml-auto">
    <DropdownMenu.Root>
      <DropdownMenu.Trigger>
        {#snippet child({ props })}
          <Button {...props} variant="outline" size="sm">
            <SlidersHorizontal data-icon="inline-start" />
            Options
          </Button>
        {/snippet}
      </DropdownMenu.Trigger>
      <DropdownMenu.Content align="end" class="min-w-56">
        <DropdownMenu.CheckboxItem
          checked={deleted}
          onCheckedChange={(checked) => {
            deleted = checked
            visit()
          }}
        >
          {deletedLabel}
        </DropdownMenu.CheckboxItem>
      </DropdownMenu.Content>
    </DropdownMenu.Root>
  </div>
</div>
