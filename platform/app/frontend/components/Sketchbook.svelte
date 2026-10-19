<script lang="ts">
  import type { Snippet } from 'svelte'
  import sketchbook from '@/assets/journal/sketchbook.webp'

  // The journal composer's frame: the artist's ring-bound sketchbook, with the content laid on its cream page. The
  // page's box below is measured off the art (2132x1440). Where the book can't fit, on phones and short windows, it
  // becomes a plain cream sheet in the cover's orange. Escape is left to the caller.
  let {
    titleId,
    onClose,
    children,
  }: {
    titleId: string
    onClose: () => void
    children: Snippet
  } = $props()
</script>

<div class="sketchbook-backdrop" role="dialog" aria-modal="true" aria-labelledby={titleId}>
  <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}></button>

  <div class="sketchbook" style:--art="url({sketchbook})">
    <div class="sketchbook-page">
      <button type="button" class="sketchbook-close" aria-label="Close" onclick={onClose}>
        <svg viewBox="0 0 12 12" class="size-3" fill="none" stroke="currentColor" stroke-width="2.2">
          <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
        </svg>
      </button>
      {@render children()}
    </div>
  </div>
</div>

<style>
  .sketchbook-backdrop {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem;
    background: rgba(4, 6, 15, 0.78);
    animation: sketchbook-fade 0.2s ease-out both;
  }

  .sketchbook {
    position: relative;
    display: flex;
    width: 100%;
    height: 100%;
    flex-direction: column;
    border: 10px solid #ffbd58;
    border-radius: 22px;
    background: #ffe1bd;
    box-shadow:
      0 0 0 2px #cc8d44,
      0 24px 60px -16px rgba(0, 0, 0, 0.9);
    animation: sketchbook-in 0.25s cubic-bezier(0.2, 0.8, 0.3, 1) both;

    /* Paper's colours, in the sketchbook's: the art's brown outlines for ink, its ring purple for anything picked. */
    --color-ink: #4b2e1a;
    --color-ink-soft: #95653a;
    --color-paper: #ffe1bd;
    --color-paper-well: #fff1de;
    --color-paper-rim: #f2bd77;
    --color-paper-edge: #e3a452;
    --color-red-700: #c2412d;
    --sb-ring: #7880f2;
    --sb-ring-deep: #555bd0;
    --sb-lavender: #b9a3fb;
    color: var(--color-ink);
  }

  .sketchbook-page {
    position: relative;
    display: flex;
    min-height: 0;
    flex: 1;
    flex-direction: column;
    padding: 1.25rem 1rem 1rem;
  }

  @media (min-width: 1024px) and (min-height: 600px) {
    .sketchbook-backdrop {
      padding: 1.5rem;
    }
    .sketchbook {
      container-type: inline-size;
      width: min(100%, 1400px, calc((100dvh - 3rem) * 2132 / 1440));
      height: auto;
      aspect-ratio: 2132 / 1440;
      border: 0;
      border-radius: 0;
      background: var(--art) center / 100% 100% no-repeat;
      box-shadow: none;
      filter: drop-shadow(0 28px 40px rgba(0, 0, 0, 0.55));
    }
    .sketchbook-page {
      position: absolute;
      top: 7.92%;
      right: 11.82%;
      bottom: 8.47%;
      left: 7.22%;
      /* Clear of the rings' holes on the left. */
      padding: 2.4cqw 2.2cqw 1.8cqw 5.2cqw;
    }
  }

  .sketchbook-close {
    position: absolute;
    top: 0.9rem;
    right: 0.9rem;
    z-index: 1;
    display: flex;
    width: 2rem;
    height: 2rem;
    cursor: pointer;
    align-items: center;
    justify-content: center;
    border: 2px solid #e3a452;
    border-radius: 9999px;
    background: #fff1de;
    color: #b0702f;
    transition:
      border-color 0.15s,
      color 0.15s,
      transform 0.15s;
  }
  .sketchbook-close:hover,
  .sketchbook-close:focus-visible {
    border-color: var(--sb-ring);
    color: var(--sb-ring-deep);
    outline: none;
    transform: rotate(90deg);
  }

  /* A pill in the rings' purple, pressed down a step like the rings are drawn. */
  .sketchbook :global(.sketch-button) {
    display: inline-flex;
    cursor: pointer;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--sb-ring-deep);
    border-radius: 9999px;
    padding: 0.6rem 1.25rem;
    background: linear-gradient(#949afb, var(--sb-ring));
    box-shadow:
      inset 0 2px 0 rgba(255, 255, 255, 0.35),
      0 3px 0 var(--sb-ring-deep);
    color: #fff;
    font-family: var(--font-outfit);
    font-size: 0.95rem;
    font-weight: 800;
    letter-spacing: 0.04em;
    transition:
      transform 0.08s,
      box-shadow 0.08s,
      filter 0.15s;
  }
  .sketchbook :global(.sketch-button:hover:not(:disabled)) {
    filter: brightness(1.06);
  }
  .sketchbook :global(.sketch-button:focus-visible) {
    outline: 2px solid var(--sb-ring-deep);
    outline-offset: 3px;
  }
  .sketchbook :global(.sketch-button:active:not(:disabled)) {
    transform: translateY(3px);
    box-shadow:
      inset 0 2px 0 rgba(255, 255, 255, 0.35),
      0 0 0 var(--sb-ring-deep);
  }
  .sketchbook :global(.sketch-button:disabled) {
    cursor: not-allowed;
    filter: saturate(0.4);
    opacity: 0.55;
  }
  .sketchbook :global(.sketch-scroll) {
    scrollbar-color: #e3a452 transparent;
    scrollbar-width: thin;
  }

  @keyframes sketchbook-fade {
    from {
      opacity: 0;
    }
  }
  @keyframes sketchbook-in {
    from {
      opacity: 0;
      transform: translateY(14px) rotate(-0.6deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .sketchbook-backdrop,
    .sketchbook {
      animation: none;
    }
  }
</style>
