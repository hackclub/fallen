<script lang="ts">
  import type { Snippet } from 'svelte'
  import { BitsConfig } from 'bits-ui'
  import AdminCommandPalette from '@/components/admin/AdminCommandPalette.svelte'
  import AdminFlash from '@/components/admin/AdminFlash.svelte'
  import AdminSidebar from '@/components/admin/AdminSidebar.svelte'
  import { adminDark } from '@/lib/adminDark.svelte'

  let { children }: { children?: Snippet } = $props()

  let paletteOpen = $state(false)
  let sidebarCollapsed = $state(true)
</script>

<svelte:head><title>Fallen Admin</title></svelte:head>

<!-- The admin theme lives on this element, so dialogs and menus portal into it instead of <body>. -->
<div class={['admin min-h-screen bg-background text-foreground antialiased', adminDark.on && 'dark']}>
  <BitsConfig defaultPortalTo=".admin">
    <AdminSidebar onSearch={() => (paletteOpen = true)} bind:collapsed={sidebarCollapsed} />
    <AdminCommandPalette bind:open={paletteOpen} />

    <div
      class={[
        'pt-10 transition-[padding] duration-200 ease-in-out sm:pt-0',
        sidebarCollapsed ? 'sm:pl-12' : 'sm:pl-56',
      ]}
    >
      <main class="t-admin-page p-6">
        <AdminFlash />
        {@render children?.()}
      </main>
    </div>
  </BitsConfig>
</div>
