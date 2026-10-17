<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'

  // A prompt's pill button with a small + at each end: cream to go ahead, outlined to back out. With `href` it's a
  // link.
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
</script>

{#snippet content()}
  <span class="ornate-plus" aria-hidden="true">+</span>
  <span class="flex-1 text-center">{@render children()}</span>
  <span class="ornate-plus" aria-hidden="true">+</span>
{/snippet}

{#if href}
  <a {href} class="ornate-button {kind} {className}">{@render content()}</a>
{:else}
  <button type="button" {...rest} class="ornate-button {kind} {className}">{@render content()}</button>
{/if}

<style>
  .ornate-button {
    display: inline-flex;
    min-width: 10rem;
    cursor: pointer;
    align-items: center;
    gap: 0.75rem;
    border: 2px solid;
    border-radius: 9999px;
    padding: 0.5rem 0.9rem;
    font-family: var(--font-outfit);
    font-size: 0.85rem;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    text-decoration: none;
    transition:
      border-color 0.15s,
      background-color 0.15s,
      transform 0.1s;
  }
  .confirm {
    border-color: #fcf9ef;
    background: #f3ead6;
    color: #11163f;
  }
  .confirm:hover:not(:disabled),
  .confirm:focus-visible {
    border-color: #dab771;
    background: #fcf9ef;
  }
  .cancel {
    border-color: #2c3680;
    background: #161d52;
    color: #9cabf7;
  }
  .cancel:hover:not(:disabled),
  .cancel:focus-visible {
    border-color: #dab771;
    color: #fcf9ef;
  }
  .ornate-button:focus-visible {
    outline: none;
  }
  .ornate-button:active:not(:disabled) {
    transform: translateY(1px);
  }
  .ornate-button:disabled {
    cursor: not-allowed;
    opacity: 0.45;
  }
  .ornate-plus {
    font-size: 0.8rem;
    line-height: 1;
    opacity: 0.45;
  }
</style>
