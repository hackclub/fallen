<script lang="ts">
  import { shared } from '@/lib/shared.svelte'

  const flash = $derived(shared().flash ?? {})
</script>

{#if flash.notice}
  <div
    class="mb-6 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800"
    role="status"
  >
    {flash.notice}
  </div>
{/if}
{#if flash.alert}
  <div class="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800" role="alert">
    {flash.alert}
  </div>
{/if}
