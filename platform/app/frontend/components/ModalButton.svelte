<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'

  // A prompt's chunky game button (game-btn in application.css): blue to go ahead, cream to back out. With `href`
  // it's a link.
  let {
    kind,
    href,
    class: className = '',
    children,
    ...rest
  }: {
    kind: 'confirm' | 'cancel'
    href?: string
    class?: string
    children: Snippet
  } & HTMLButtonAttributes = $props()

  const classes = $derived(
    `game-btn min-w-40 ${kind === 'confirm' ? 'game-btn-blue' : 'game-btn-white'} ${className}`,
  )
</script>

{#if href}
  <a {href} class={classes}>{@render children()}</a>
{:else}
  <button type="button" {...rest} class={classes}>{@render children()}</button>
{/if}
