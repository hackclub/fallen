<script lang="ts">
  import '@/components/dialog/dialog.css'
  import type { Snippet } from 'svelte'
  import { animate, type AnimationPlaybackControls } from 'motion'
  import { prefersReducedMotion } from '@/components/dialog/motion'

  // The frame every prompt sits in, in the onboarding dialog's game style: a cream game-card that pops up with a
  // tilted title tab on its top edge (application.css). Forms built for paper (ProjectFields) sit on it unchanged.
  // Escape is left to the caller, which may want it to step back rather than close. Without `onClose` it can't be
  // dismissed. `backdropClass` moves the panel within the backdrop.
  let {
    titleId,
    title,
    eyebrow,
    onClose,
    class: className = 'max-w-xl',
    backdropClass = '',
    children,
  }: {
    titleId: string
    title: string
    eyebrow?: string
    onClose?: () => void
    class?: string
    backdropClass?: string
    children: Snippet
  } = $props()

  // When what's inside changes (a form's next step, an error appearing), the card springs to its new height instead
  // of snapping. ResizeObserver runs before paint, so the old height is pinned before the new content shows.
  function springHeight(el: HTMLElement) {
    const content = el.firstElementChild as HTMLElement
    let last = 0
    let controls: AnimationPlaybackControls | undefined
    const observer = new ResizeObserver(() => {
      const height = content.offsetHeight
      if (last && height !== last) {
        // Mid-spring the box is at its animated height; otherwise layout already moved it, so start from the last.
        el.style.height = `${el.style.height ? el.offsetHeight : last}px`
        controls?.stop()
        const spring = animate(
          el,
          { height: `${height}px` },
          prefersReducedMotion() ? { duration: 0 } : { type: 'spring', stiffness: 420, damping: 34 },
        )
        controls = spring
        // Back to its natural height once settled, unless a newer spring has taken over.
        spring.finished.then(() => controls === spring && (el.style.height = ''))
      }
      last = height
    })
    observer.observe(content)
    return () => {
      observer.disconnect()
      controls?.stop()
    }
  }
</script>

<div
  class="modal-backdrop fixed inset-0 z-50 flex items-center justify-center overflow-auto px-3 pt-10 pb-4 md:px-6 md:pt-12 {backdropClass}"
  role="dialog"
  aria-modal="true"
  aria-labelledby={titleId}
>
  {#if onClose}
    <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}
    ></button>
  {/if}

  <div class="modal-card game-card relative flex max-h-full w-full flex-col {className}">
    <header class={['relative -mt-7 mb-2 flex justify-center', onClose ? 'px-14' : 'px-4']}>
      <!-- Pops again when the title changes, so a new step reads as one. -->
      {#key title}
        <h2 id={titleId} class="modal-tab game-tab max-w-full truncate">
          {#if eyebrow}<span class="mr-1 text-base opacity-80 md:text-lg">{eyebrow}</span>{/if}{title}
        </h2>
      {/key}
    </header>

    {#if onClose}
      <button
        type="button"
        onclick={onClose}
        aria-label="Close"
        class="game-btn game-btn-white absolute -top-4 -right-3 z-10 size-11 min-h-0 rounded-full p-0 md:-right-4"
      >
        <svg viewBox="0 0 12 12" class="size-3.5" fill="none" stroke="currentColor" stroke-width="2.6">
          <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
        </svg>
      </button>
    {/if}

    <div class="modal-body min-h-0" {@attach springHeight}>
      <div>{@render children()}</div>
    </div>
  </div>
</div>

<style>
  .modal-backdrop {
    background: rgba(6, 9, 30, 0.72);
    animation: modal-fade 0.2s ease-out both;
  }
  .modal-card {
    animation: modal-pop 0.42s cubic-bezier(0.34, 1.56, 0.64, 1) both;
  }
  /* Clipped while it springs, with room left for the buttons' ledges and focus rings. */
  .modal-body {
    overflow: clip;
    overflow-clip-margin: 8px;
  }
  .modal-tab {
    animation: modal-tab 0.45s cubic-bezier(0.34, 1.7, 0.64, 1) 0.08s both;
  }
  /* Inputs stand out from the cream as white wells, lit blue when focused like the dialog's choices. */
  .modal-card :global(.paper-input) {
    border: 2px solid var(--color-paper-rim);
    background: #fffdf8;
  }
  .modal-card :global(.paper-input:focus) {
    border-color: #1cb0f6;
  }
  @keyframes modal-fade {
    from {
      opacity: 0;
    }
  }
  @keyframes modal-pop {
    from {
      opacity: 0;
      transform: translateY(24px) scale(0.86);
    }
  }
  @keyframes modal-tab {
    from {
      opacity: 0;
      transform: translateY(14px) scale(0.5) rotate(8deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .modal-backdrop,
    .modal-card,
    .modal-tab {
      animation: none;
    }
  }
</style>
