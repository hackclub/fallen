<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { Pagy } from '@/types'

  // Previous/next for a paginated prop. Unstyled beyond layout so it fits the public (dark) and admin pages;
  // pass the button classes of the page it sits on.
  let {
    pagy,
    noun = 'items',
    class: className = '',
    buttonClass = 'btn-secondary',
  }: { pagy: Pagy; noun?: string; class?: string; buttonClass?: string } = $props()

  function goTo(pageNumber: number) {
    const url = new URL(window.location.href)
    url.searchParams.set('page', String(pageNumber))
    router.get(url.pathname + url.search, {}, { preserveState: true, preserveScroll: true })
  }
</script>

{#if pagy.pages > 1}
  <nav class="flex items-center justify-between text-sm {className}" aria-label="Pagination">
    <button
      type="button"
      class={buttonClass}
      disabled={!pagy.prev}
      onclick={() => pagy.prev && goTo(pagy.prev)}
    >
      Previous
    </button>
    <span>Page {pagy.page} of {pagy.pages} · {pagy.count} {noun}</span>
    <button
      type="button"
      class={buttonClass}
      disabled={!pagy.next}
      onclick={() => pagy.next && goTo(pagy.next)}
    >
      Next
    </button>
  </nav>
{/if}
