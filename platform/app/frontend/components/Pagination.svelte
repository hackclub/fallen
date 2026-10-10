<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { Pagy } from '@/types'

  let { pagy }: { pagy: Pagy } = $props()

  function goTo(pageNumber: number) {
    const url = new URL(window.location.href)
    url.searchParams.set('page', String(pageNumber))
    router.get(url.pathname + url.search, {}, { preserveState: true, preserveScroll: true })
  }
</script>

{#if pagy.pages > 1}
  <nav class="mt-6 flex items-center justify-between text-sm" aria-label="Pagination">
    <button
      type="button"
      class="btn-secondary"
      disabled={!pagy.prev}
      onclick={() => pagy.prev && goTo(pagy.prev)}
    >
      Previous
    </button>
    <span class="text-stone-600">Page {pagy.page} of {pagy.pages} · {pagy.count} total</span>
    <button
      type="button"
      class="btn-secondary"
      disabled={!pagy.next}
      onclick={() => pagy.next && goTo(pagy.next)}
    >
      Next
    </button>
  </nav>
{/if}
