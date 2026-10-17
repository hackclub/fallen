<script lang="ts">
  import type { Snippet } from 'svelte'
  import { starPath } from '@/components/GoldFrame.svelte'

  // The frame every prompt sits in: a night-blue panel with a lighter rim, a gold pin in each corner and a title
  // over a hooked rule. Inside it the paper colours are swapped for night ones (see .ornate-panel), so forms built
  // for paper (ProjectFields, MarkdownEditor) read right on it unchanged. Escape is left to the caller, which may
  // want it to step back rather than close. Without `onClose` it can't be dismissed.
  let {
    titleId,
    title,
    eyebrow,
    onClose,
    class: className = 'max-w-xl',
    children,
  }: {
    titleId: string
    title: string
    eyebrow?: string
    onClose?: () => void
    class?: string
    children: Snippet
  } = $props()
</script>

<div
  class="ornate-backdrop fixed inset-0 z-50 flex items-center justify-center overflow-auto p-2 md:p-6"
  role="dialog"
  aria-modal="true"
  aria-labelledby={titleId}
>
  {#if onClose}
    <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}
    ></button>
  {/if}

  <div class="ornate-rim relative flex max-h-full w-full flex-col rounded-[26px] p-[7px] {className}">
    {#each ['top-2 left-2', 'top-2 right-2', 'bottom-2 left-2', 'right-2 bottom-2'] as corner (corner)}
      <svg viewBox="0 0 29.1 29.1" class="absolute z-10 size-2.5 {corner}" aria-hidden="true">
        <path d={starPath} fill="#dab771" />
      </svg>
    {/each}

    <div class="ornate-panel relative flex min-h-0 flex-1 flex-col rounded-[20px]">
      <header class="relative px-12 pt-6 pb-4 text-center md:pt-8">
        {#if eyebrow}
          <p class="mb-1 font-outfit text-[11px] font-bold tracking-[0.2em] text-gold/80 uppercase">
            {eyebrow}
          </p>
        {/if}
        <h2
          id={titleId}
          class="font-outfit text-xl font-extrabold tracking-wide break-words text-cream uppercase md:text-[26px]"
        >
          {title}
        </h2>
        <svg
          viewBox="0 0 240 12"
          class="mx-auto mt-1.5 h-3 w-60 max-w-full text-gold"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <circle cx="4" cy="6" r="2.5" fill="currentColor" stroke="none" />
          <circle cx="236" cy="6" r="2.5" fill="currentColor" stroke="none" />
          <path d="M4 6H104c6 0 7 4 4 5.5-3 1.5-5-1-3-3" />
          <path d="M236 6H136c-6 0-7 4-4 5.5 3 1.5 5-1 3-3" />
        </svg>

        {#if onClose}
          <button
            type="button"
            onclick={onClose}
            aria-label="Close"
            class="absolute top-4 right-4 flex size-8 cursor-pointer items-center justify-center rounded-full border-2 border-[#2c3680] bg-[#161d52] text-light-blue transition-colors hover:border-gold hover:text-cream focus-visible:border-gold focus-visible:outline-none md:top-5 md:right-5"
          >
            <svg viewBox="0 0 12 12" class="size-3" fill="none" stroke="currentColor" stroke-width="2.2">
              <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
            </svg>
          </button>
        {/if}
      </header>

      {@render children()}
    </div>
  </div>
</div>

<style>
  .ornate-backdrop {
    background: rgba(4, 6, 15, 0.78);
    animation: ornate-fade 0.2s ease-out both;
  }
  .ornate-rim {
    background: #1b2259;
    box-shadow:
      0 0 0 2px #070b24,
      0 24px 60px -16px rgba(0, 0, 0, 0.9);
    animation: ornate-in 0.22s ease-out both;
  }
  .ornate-panel {
    background: #10153d;
    box-shadow:
      0 0 0 2px #070b24,
      inset 0 2px 0 rgba(255, 255, 255, 0.04);

    /* Paper's colours, at night. Everything inside that's drawn with text-ink, bg-paper-well, paper-input and the
       like picks these up. */
    --color-ink: #fcf9ef;
    --color-ink-soft: #9cabf7;
    --color-paper: #10153d;
    --color-paper-well: #0a0e2c;
    --color-paper-rim: #1b2259;
    --color-paper-edge: #2c3680;
    --color-red-700: #ff8f9c;
    --font-display: var(--font-outfit);
    color: var(--color-ink);
  }
  .ornate-panel :global(.font-display) {
    font-weight: 700;
  }
  .ornate-panel :global(.paper-input) {
    border-color: #2c3680;
  }
  .ornate-panel :global(.paper-input:focus) {
    border-color: #dab771;
  }
  @keyframes ornate-fade {
    from {
      opacity: 0;
    }
  }
  @keyframes ornate-in {
    from {
      opacity: 0;
      transform: scale(0.97);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .ornate-backdrop,
    .ornate-rim {
      animation: none;
    }
  }
</style>
