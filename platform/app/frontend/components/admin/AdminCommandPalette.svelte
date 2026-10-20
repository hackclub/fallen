<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Moon from '@lucide/svelte/icons/moon'
  import Sun from '@lucide/svelte/icons/sun'
  import * as Command from '@/components/admin/ui/command'
  import { adminDark, toggleAdminDark } from '@/lib/adminDark.svelte'
  import { adminNav, type AdminNavItem } from '@/lib/adminNav'

  let { open = $bindable(false) }: { open?: boolean } = $props()

  function onkeydown(event: KeyboardEvent) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault()
      open = !open
    }
  }

  function go(item: AdminNavItem) {
    open = false
    router.visit(item.href)
  }

  function toggleDark() {
    open = false
    toggleAdminDark()
  }
</script>

<svelte:window {onkeydown} />

<Command.Dialog bind:open title="Go to" description="Jump to an admin page" class="sm:max-w-md">
  <Command.Input placeholder="Go to..." />
  <Command.List>
    <Command.Empty>No results found.</Command.Empty>
    {#each adminNav as section (section.title)}
      <Command.Group heading={section.title}>
        {#each section.items as item (item.href)}
          <Command.Item value={item.label} onSelect={() => go(item)}>
            <item.icon />
            {item.label}
          </Command.Item>
        {/each}
      </Command.Group>
    {/each}
    <Command.Group heading="Settings">
      <Command.Item value="Toggle dark mode" onSelect={toggleDark}>
        {#if adminDark.on}<Sun />{:else}<Moon />{/if}
        {adminDark.on ? 'Light mode' : 'Dark mode'}
      </Command.Item>
    </Command.Group>
  </Command.List>
</Command.Dialog>
