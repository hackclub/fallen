<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import type { Component } from 'svelte'

  // The sign-off desk lives in the private hackclub/fallen-desk repo (vendor/desk). Rails only renders this page when
  // that repo is mounted.
  const desks = import.meta.glob<{ default: Component<Record<string, unknown>> }>('@desk/Desk.svelte')
  const load = Object.values(desks)[0]

  let props: Record<string, unknown> = $props()
</script>

{#if load}
  {#await load() then desk}
    <desk.default {...props} />
  {/await}
{:else}
  <p class="text-sm text-muted-foreground">
    This build has no sign-off desk. Mount vendor/desk and build again.
  </p>
{/if}
