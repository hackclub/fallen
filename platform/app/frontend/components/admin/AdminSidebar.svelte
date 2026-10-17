<script lang="ts">
  import { Link, page, usePage } from '@inertiajs/svelte'
  import ChevronsLeft from '@lucide/svelte/icons/chevrons-left'
  import ChevronsRight from '@lucide/svelte/icons/chevrons-right'
  import LogOut from '@lucide/svelte/icons/log-out'
  import Moon from '@lucide/svelte/icons/moon'
  import Search from '@lucide/svelte/icons/search'
  import Sun from '@lucide/svelte/icons/sun'
  import { Kbd } from '@/components/admin/ui/kbd'
  import Wordmark from '@/components/Wordmark.svelte'
  import { adminDark, toggleAdminDark } from '@/lib/adminDark.svelte'
  import { adminNav, isActive } from '@/lib/adminNav'
  import { home, adminRoot } from '@/routes'
  import type { AdminSharedProps } from '@/types'

  let { onSearch, collapsed = $bindable() }: { onSearch: () => void; collapsed?: boolean } = $props()

  const COLLAPSED_KEY = 'admin-sidebar-collapsed'
  const shared = $derived(usePage<AdminSharedProps>().props)
  const user = $derived(shared.auth.user)
  const pathname = $derived(page.url.split('?')[0])

  collapsed = initiallyCollapsed()

  function initiallyCollapsed() {
    const narrow = window.innerWidth < 640
    const stored = localStorage.getItem(COLLAPSED_KEY)
    return stored === null ? narrow : stored !== '0'
  }

  function toggle() {
    collapsed = !collapsed
    localStorage.setItem(COLLAPSED_KEY, collapsed ? '1' : '0')
  }

  const iconButton =
    'shrink-0 cursor-pointer rounded p-1 text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
</script>

<!-- On phones the open sidebar covers the page; tapping outside closes it. -->
<button
  type="button"
  aria-label="Close sidebar"
  tabindex="-1"
  class="fixed inset-0 z-40 bg-black/20 transition-opacity duration-200 sm:hidden {collapsed
    ? 'pointer-events-none opacity-0'
    : 'opacity-100'}"
  onclick={toggle}
></button>

{#if collapsed}
  <button
    type="button"
    class="{iconButton} fixed top-3 left-3 z-30 sm:hidden"
    title="Open sidebar"
    onclick={toggle}
  >
    <ChevronsRight class="size-4" />
  </button>
{/if}

<aside
  class="fixed inset-y-0 left-0 z-50 flex flex-col overflow-hidden border-r border-sidebar-border bg-sidebar text-sidebar-foreground transition-transform duration-200 ease-in-out sm:transition-[width] {collapsed
    ? 'w-56 -translate-x-full sm:w-12 sm:translate-x-0'
    : 'w-56 translate-x-0'}"
>
  <div class="flex items-center border-b border-sidebar-border px-2.5 py-3">
    {#if !collapsed}
      <Link
        href={adminRoot()}
        class="flex min-w-0 flex-1 items-center gap-2 text-sm font-semibold tracking-tight whitespace-nowrap"
      >
        <Wordmark class="h-9" />
        Admin
      </Link>
    {/if}
    <button
      type="button"
      class={iconButton}
      title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
      onclick={toggle}
    >
      {#if collapsed}<ChevronsRight class="size-4" />{:else}<ChevronsLeft class="size-4" />{/if}
    </button>
  </div>

  <div class="px-1.5 pt-2">
    <button
      type="button"
      title="Search (Ctrl K)"
      class="flex h-8 w-full cursor-pointer items-center gap-2 rounded-md px-2 text-sm whitespace-nowrap text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
      onclick={onSearch}
    >
      <Search class="size-4 shrink-0" />
      {#if !collapsed}
        <span class="flex-1 text-left">Search</span>
        <Kbd>⌘K</Kbd>
      {/if}
    </button>
  </div>

  <nav class="flex-1 overflow-y-auto px-1.5 py-2">
    {#each adminNav as section, i (section.title)}
      {#if i > 0}<div class="mx-2 my-2 border-t border-sidebar-border"></div>{/if}
      <div class="space-y-0.5">
        {#each section.items as item (item.href)}
          {@const active = isActive(item, pathname)}
          {@const stat = item.statKey && shared.admin_stats ? shared.admin_stats[item.statKey] : null}
          {@const itemClass = `t-nav-item flex h-8 items-center gap-2 rounded-md px-2 py-1.5 text-sm whitespace-nowrap transition-[background-color,color,transform] duration-200 ease-out ${
            active
              ? 'bg-sidebar-accent font-medium text-sidebar-accent-foreground'
              : 'text-muted-foreground hover:translate-x-0.5 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
          }`}
          {#snippet content()}
            <item.icon class="size-4 shrink-0" />
            {#if !collapsed}
              <span class="flex-1">{item.label}</span>
              {#if stat != null}
                {#key stat}
                  <span
                    class="t-nav-badge rounded-full bg-muted px-1.5 py-0.5 text-[10px] leading-none font-medium text-muted-foreground"
                  >
                    {stat}
                  </span>
                {/key}
              {/if}
            {/if}
          {/snippet}
          {#if item.external}
            <a href={item.href} title={item.label} data-active={active} class={itemClass}
              >{@render content()}</a
            >
          {:else}
            <Link
              href={item.href}
              prefetch
              cacheFor="30s"
              title={item.label}
              data-active={active}
              class={itemClass}
            >
              {@render content()}
            </Link>
          {/if}
        {/each}
      </div>
    {/each}
  </nav>

  <div class="overflow-hidden border-t border-sidebar-border px-1.5 py-2">
    <div class="flex items-center gap-2 px-1 whitespace-nowrap">
      {#if user}
        <img src={user.avatar} alt="" class="size-6 shrink-0 rounded-full bg-muted object-cover" />
        {#if !collapsed}<span class="flex-1 truncate text-xs text-muted-foreground">{user.display_name}</span
          >{/if}
      {/if}
      {#if !collapsed}
        <Link href={home.index()} title="Leave admin" class={iconButton}><LogOut class="size-4" /></Link>
        <button
          type="button"
          class={iconButton}
          title={adminDark.on ? 'Switch to light mode' : 'Switch to dark mode'}
          onclick={toggleAdminDark}
        >
          {#if adminDark.on}<Sun class="size-4" />{:else}<Moon class="size-4" />{/if}
        </button>
      {/if}
    </div>
  </div>
</aside>
