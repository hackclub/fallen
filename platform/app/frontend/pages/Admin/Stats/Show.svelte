<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import type { ComponentProps } from 'svelte'
  import ProgramStats from '@/components/admin/ProgramStats.svelte'
  import { adminStats } from '@/routes'

  let props: Omit<ComponentProps<typeof ProgramStats>, 'url'> = $props()
</script>

<svelte:head><title>Stats · Fallen Admin</title></svelte:head>

<ProgramStats {...props} url={(range) => adminStats.show({ query: range === '30d' ? {} : { range } }).url} />
