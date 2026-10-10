<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { impersonation } from '@/routes'
  import { shared } from '@/lib/shared.svelte'

  const active = $derived(shared().impersonation)
</script>

{#if active}
  <div class="flex items-center justify-center gap-3 bg-hc-orange px-4 py-2 text-sm font-medium text-white">
    <span>Browsing as another user (admin: {active.impersonator_name}).</span>
    <button type="button" class="btn-secondary px-3 py-1" onclick={() => router.visit(impersonation())}>
      Stop impersonating
    </button>
  </div>
{/if}
