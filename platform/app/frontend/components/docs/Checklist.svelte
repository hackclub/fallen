<script lang="ts">
  import type { Snippet } from 'svelte'
  import * as sfx from '@/lib/sfx'

  // A boxed checklist in the docs: every item of the Markdown lists inside becomes a checkbox to tick off while
  // getting a project ready. Ticks are not saved.
  let { children }: { children: Snippet } = $props()

  function checkboxes(node: HTMLElement) {
    for (const item of node.querySelectorAll('li')) {
      item.role = 'checkbox'
      item.tabIndex = 0
      item.ariaChecked = 'false'
    }
  }

  function tick(event: Event) {
    const target = event.target as HTMLElement
    const item = target.closest('li')
    if (!item || target.closest('a')) return
    const on = item.ariaChecked !== 'true'
    item.ariaChecked = String(on)
    sfx.toggle(on)
  }

  function onkeydown(event: KeyboardEvent) {
    if (event.key !== ' ' && event.key !== 'Enter') return
    event.preventDefault()
    tick(event)
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div {@attach checkboxes} onclick={tick} {onkeydown} class="checklist">
  {@render children()}
</div>
