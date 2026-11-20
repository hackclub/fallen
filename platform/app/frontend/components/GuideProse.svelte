<script lang="ts">
  import type { Snippet } from 'svelte'

  // Long-form guide text (an .mdx body): Geist body, Nunito Sans headings, one even rhythm between blocks.
  let { children }: { children?: Snippet } = $props()
</script>

<div class="guide mt-6">
  {@render children?.()}
</div>

<style>
  /* Modelled on Hack Club's bashed guides: plain white headings, the same gap between every block, pale dashed rules,
     and notes and code as soft boxes a shade off the card. */
  .guide {
    font-size: 16px;
    line-height: 1.5;
    color: rgb(255 255 255 / 0.85);
  }
  .guide :global(> * + *) {
    margin-top: 1rem;
  }

  .guide :global(h2),
  .guide :global(h3),
  .guide :global(h4) {
    font-family: var(--font-sans);
    font-weight: 800;
    line-height: 1.25;
    color: #fff;
    scroll-margin-top: 1.5rem;
  }
  .guide :global(h2) {
    margin-top: 2.25rem;
    border-bottom: 1px dashed rgb(255 255 255 / 0.35);
    padding-bottom: 0.5rem;
    font-size: 1.5rem;
  }
  .guide :global(h3) {
    margin-top: 1.75rem;
    font-size: 1.2rem;
  }
  .guide :global(h4) {
    margin-top: 1.5rem;
    font-size: 1rem;
  }
  .guide :global(:is(h2, h3, h4) + *) {
    margin-top: 0.6rem;
  }

  .guide :global(strong) {
    font-weight: 600;
    color: #fff;
  }
  .guide :global(a) {
    color: var(--color-sky-gold);
    text-decoration: underline;
    text-decoration-color: rgb(232 207 138 / 0.4);
    text-underline-offset: 3px;
  }
  .guide :global(a:hover) {
    text-decoration-color: var(--color-sky-gold);
  }

  .guide :global(ul) {
    list-style: disc;
    padding-left: 1.25rem;
  }
  .guide :global(ol) {
    list-style: decimal;
    padding-left: 1.25rem;
  }
  .guide :global(li + li),
  .guide :global(li > :is(ul, ol)) {
    margin-top: 0.3rem;
  }
  .guide :global(li::marker) {
    color: rgb(255 255 255 / 0.4);
  }

  .guide :global(hr) {
    margin: 2rem 0;
    border: 0;
    border-top: 1px dashed rgb(255 255 255 / 0.35);
  }

  .guide :global(code) {
    border-radius: 0.375rem;
    background: rgb(255 255 255 / 0.1);
    padding: 0.1rem 0.35rem;
    font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.875em;
    color: #fff;
  }
  .guide :global(pre) {
    overflow-x: auto;
    border-radius: 0.75rem;
    background: rgb(0 0 0 / 0.25);
    padding: 1rem;
    font-size: 0.875rem;
  }
  .guide :global(pre code) {
    background: none;
    padding: 0;
  }

  /* The usual Markdown quote: a bar down the left, on a slightly lighter panel. */
  .guide :global(blockquote) {
    border-left: 4px solid rgb(255 255 255 / 0.35);
    border-radius: 0 0.375rem 0.375rem 0;
    background: rgb(255 255 255 / 0.05);
    padding: 0.75rem 1rem;
    color: rgb(255 255 255 / 0.85);
  }
  .guide :global(blockquote > * + *) {
    margin-top: 0.6rem;
  }

  .guide :global(details) {
    border-radius: 0.75rem;
    border: 1px dashed rgb(255 255 255 / 0.25);
    padding: 0.6rem 1.1rem;
  }
  .guide :global(details[open] > summary) {
    margin-bottom: 0.6rem;
  }
  .guide :global(details > :not(summary) + *) {
    margin-top: 0.6rem;
  }
  .guide :global(summary) {
    cursor: pointer;
    font-weight: 600;
    color: #fff;
  }

  .guide :global(img) {
    display: block;
    max-width: 100%;
    height: auto;
    border-radius: 0.75rem;
  }
  /* A toolbar icon named inside a sentence sits on the line with the words. */
  .guide :global(img[src$='-icon.png']) {
    display: inline-block;
    height: 1.75em;
    width: auto;
    margin: -0.25em 0.15em 0;
    border-radius: 0.25rem;
    vertical-align: middle;
  }

  /* Block so a wide table scrolls inside the card instead of widening the page on a phone. */
  .guide :global(table) {
    display: block;
    max-width: 100%;
    overflow-x: auto;
    border-collapse: collapse;
    font-size: 0.9rem;
  }
  .guide :global(th),
  .guide :global(td) {
    border: 1px solid rgb(255 255 255 / 0.12);
    padding: 0.45rem 0.8rem;
    text-align: left;
  }
  .guide :global(th) {
    background: rgb(255 255 255 / 0.06);
    font-weight: 700;
    color: #fff;
  }
</style>
