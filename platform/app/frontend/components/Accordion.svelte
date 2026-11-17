<script lang="ts">
  // Questions that open one at a time (the landing FAQ, the Visa page): native <details>, so it works without JS.
  // With it, opening and closing are animated: the answer's height eases open while its text fades and drops into
  // place, and the highlight and the ornament parting the line above follow `shown`, which changes on the click
  // rather than when the closing animation finishes. `size` is the landing's big type or a smaller one for panels.
  import { untrack, type Snippet } from 'svelte'
  import DiamondOrnament from '@/components/DiamondOrnament.svelte'

  let {
    items: faqs,
    size = 'lg',
    itemClass = '',
  }: { items: { question: string; answer: Snippet }[]; size?: 'lg' | 'md'; itemClass?: string } = $props()

  const opening = { duration: 450, easing: 'cubic-bezier(0.22, 1, 0.36, 1)' }
  const closing = { duration: 280, easing: 'cubic-bezier(0.4, 0, 0.6, 1)' }

  let shown = $state(-1) // the open item; none to start with
  const items: HTMLDetailsElement[] = $state([])

  function toggle(event: MouseEvent, i: number) {
    event.preventDefault()
    const next = shown === i ? -1 : i
    items.forEach((item, j) => {
      if (j === next || j === shown) animate(item, j === next)
    })
    shown = next
  }

  // from wherever it is, so a click mid-animation turns it round instead of jumping
  function animate(item: HTMLDetailsElement, open: boolean) {
    const body = item.querySelector<HTMLElement>('[data-answer]')!
    // a closed item's answer is still laid out, just not shown
    const from = item.open ? body.getBoundingClientRect().height : 0
    for (const animation of body.getAnimations({ subtree: true })) animation.cancel()
    item.open = true
    const to = open ? body.scrollHeight : 0
    const timing = matchMedia('(prefers-reduced-motion: reduce)').matches
      ? { duration: 0 }
      : open
        ? opening
        : closing
    const height = body.animate({ height: [`${from}px`, `${to}px`] }, timing)
    body.firstElementChild!.animate(
      open
        ? { opacity: [0, 1], translate: ['0 -8px', '0 0'] }
        : { opacity: [1, 0], translate: ['0 0', '0 -4px'] },
      { ...timing, delay: open ? 70 : 0, fill: 'both' },
    )
    height.onfinish = () => {
      if (!open) item.open = false
      for (const animation of body.getAnimations({ subtree: true })) animation.cancel()
    }
  }

  // bound rather than set, so updating `shown` never re-applies a stale open or closed state mid-animation
  // the questions are fixed for the page's life, so the first list is the only one
  const opened = $state(untrack(() => faqs.map(() => false)))
</script>

{#each faqs as faq, i (faq.question)}
  <details
    bind:this={items[i]}
    bind:open={opened[i]}
    data-shown={shown === i || undefined}
    class={['group relative border-bright-blue/40 last-of-type:border-b-2', itemClass]}
    ontoggle={() => {
      // opened by the browser itself, as find in page does: catch up, closing the one that was open
      if (!items[i].open || shown === i) return
      if (shown >= 0) animate(items[shown], false)
      shown = i
    }}
  >
    <!-- the highlight, faded rather than switched, so it goes on and off with the answer -->
    <div
      class="pointer-events-none absolute inset-0 bg-linear-to-r from-transparent via-bright-blue/15 to-transparent opacity-0 transition-opacity duration-300 group-data-shown:opacity-100"
      aria-hidden="true"
    ></div>
    <summary
      class={[
        'relative flex cursor-pointer list-none items-center gap-4 font-lora font-semibold text-cream [&::-webkit-details-marker]:hidden',
        size === 'lg' ? 'px-4 py-5 text-xl md:px-6 md:text-2xl' : 'px-4 py-4 text-lg md:px-5',
      ]}
      onclick={(event) => toggle(event, i)}
    >
      {faq.question}
      <!-- The line above each item, in two halves that part for the ornament as the item opens. The panel behind
             is a gradient, so nothing solid could fill the diamonds: the line stops short of them instead, and the
             ornament is the line's colour at the same opacity. -->
      <span
        class="pointer-events-none absolute -top-0.5 right-1/2 left-0 h-0.5 bg-bright-blue/40 transition-[right] duration-500 ease-out group-data-shown:right-[calc(50%+24px)]"
        aria-hidden="true"
      ></span>
      <span
        class="pointer-events-none absolute -top-0.5 right-0 left-1/2 h-0.5 bg-bright-blue/40 transition-[left] duration-500 ease-out group-data-shown:left-[calc(50%+24px)]"
        aria-hidden="true"
      ></span>
      <DiamondOrnament
        class="pointer-events-none absolute -top-px left-1/2 z-10 -translate-1/2 scale-50 rotate-90 text-bright-blue opacity-0 transition duration-500 ease-out group-data-shown:scale-100 group-data-shown:rotate-0 group-data-shown:opacity-40"
      />
    </summary>
    <div data-answer class="relative overflow-hidden">
      <p
        class={[
          'max-w-[44em] text-pale-blue',
          size === 'lg' ? 'px-4 pb-6 text-lg md:px-6 md:text-xl' : 'px-4 pb-5 text-base md:px-5',
        ]}
      >
        {@render faq.answer()}
      </p>
    </div>
  </details>
{/each}
