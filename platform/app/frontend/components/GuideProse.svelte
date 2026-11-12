<script lang="ts">
  import type { Snippet } from 'svelte'

  // Long-form guide text (an .mdx body) in plain Geist with strong headings, call-out notes, code and tables.
  let { children }: { children?: Snippet } = $props()
</script>

<div class="guide prose-docs mt-6">
  {@render children?.()}
</div>

<style>
  /* Plain Geist and strong shapes, so every heading, note, code snippet and table stands out. */
  .guide {
    font-family: inherit;
    font-size: 16px;
    line-height: 1.7;
    color: rgb(255 255 255 / 0.92);
  }
  .guide :global(h2),
  .guide :global(h3),
  .guide :global(h4) {
    font-family: inherit;
    scroll-margin-top: 1.5rem;
  }
  .guide :global(h2) {
    margin-top: 2.5rem;
    border-bottom: 2px solid rgb(255 255 255 / 0.2);
    padding: 0 0 0.4rem;
    font-size: 1.5rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    color: #fff;
  }
  .guide :global(h3) {
    margin-top: 1.75rem;
    font-size: 1.15rem;
    font-weight: 700;
    color: var(--color-sky-gold);
  }
  .guide :global(strong) {
    font-weight: 700;
    color: #fff;
  }
  .guide :global(a) {
    font-weight: 600;
    color: var(--color-sky-gold);
    text-decoration: underline;
    text-underline-offset: 3px;
  }
  .guide :global(code) {
    border: 1px solid rgb(255 255 255 / 0.2);
    border-radius: 0.25rem;
    background: rgb(255 255 255 / 0.1);
    padding: 0.1rem 0.4rem;
    font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.88em;
    color: #fff;
  }
  /* Notes and tips read as call-out boxes, not italic quotes. */
  .guide :global(blockquote) {
    border: 0;
    border-left: 5px solid var(--color-sky-gold);
    border-radius: 0.25rem;
    background: rgb(232 207 138 / 0.08);
    padding: 0.9rem 1.1rem;
    font-style: normal;
    color: #fff;
  }
  .guide :global(blockquote > * + *) {
    margin-top: 0.6rem;
  }
  .guide :global(img) {
    border-radius: 0.25rem;
  }
  .guide :global(li::marker) {
    font-weight: 700;
    color: var(--color-sky-gold);
  }
  .guide :global(table) {
    border-collapse: collapse;
    font-size: 0.9rem;
  }
  .guide :global(th),
  .guide :global(td) {
    border: 1px solid rgb(255 255 255 / 0.25);
    padding: 0.5rem 0.9rem;
  }
  .guide :global(th) {
    background: rgb(255 255 255 / 0.12);
    font-weight: 700;
    color: #fff;
  }
</style>
