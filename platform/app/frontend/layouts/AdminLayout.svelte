<script lang="ts">
  import type { Snippet } from 'svelte'
  import { Link, page } from '@inertiajs/svelte'
  import DefaultLayout from '@/layouts/DefaultLayout.svelte'
  import { adminRoot, adminUsers } from '@/routes'

  let { children }: { children?: Snippet } = $props()

  const links = [
    { href: adminRoot().url, label: 'Dashboard', exact: true },
    { href: adminUsers.index().url, label: 'Users', exact: false },
  ]
  const current = $derived(page.url.split('?')[0])
  const active = (href: string, exact: boolean) => (exact ? current === href : current.startsWith(href))
</script>

<DefaultLayout>
  <div class="grid gap-8 md:grid-cols-[180px_1fr]">
    <aside class="space-y-1">
      <p class="mb-2 px-3 text-xs font-semibold tracking-wide text-stone-500 uppercase">Admin</p>
      {#each links as link (link.href)}
        <Link
          href={link.href}
          class="block rounded-lg px-3 py-2 text-sm font-medium {active(link.href, link.exact)
            ? 'bg-hc-red/10 text-hc-red'
            : 'text-stone-700 hover:bg-stone-100'}"
        >
          {link.label}
        </Link>
      {/each}
      <a
        href="/admin/jobs"
        class="block rounded-lg px-3 py-2 text-sm font-medium text-stone-700 hover:bg-stone-100"
      >
        Jobs ↗
      </a>
    </aside>
    <section class="min-w-0">
      {@render children?.()}
    </section>
  </div>
</DefaultLayout>
