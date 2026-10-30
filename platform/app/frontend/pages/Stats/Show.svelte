<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import type { ComponentProps } from 'svelte'
  import { BitsConfig } from 'bits-ui'
  import { Link } from '@inertiajs/svelte'
  import ProgramStats from '@/components/admin/ProgramStats.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { adminDark } from '@/lib/adminDark.svelte'
  import { root, stats } from '@/routes'

  let props: Omit<ComponentProps<typeof ProgramStats>, 'url'> = $props()
</script>

<svelte:head><title>Stats · Fallen</title></svelte:head>

<!-- The charts are admin components, so the page wears the admin theme (see AdminLayout). -->
<div class={['admin min-h-screen bg-background text-foreground antialiased', adminDark.on && 'dark']}>
  <BitsConfig defaultPortalTo=".admin">
    <div class="mx-auto max-w-7xl p-6">
      <Link href={root()} class="mb-6 inline-block"><Wordmark class="h-5" /></Link>
      <ProgramStats {...props} url={(range) => stats.show({ query: range === '30d' ? {} : { range } }).url} />
    </div>
  </BitsConfig>
</div>
