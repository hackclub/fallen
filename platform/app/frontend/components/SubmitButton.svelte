<script lang="ts">
  // The sketchbook's submit button (sketch-button, Sketchbook.svelte). While `busy` it stays pressed in with
  // stripes running across it and the label's dots hopping, rather than greying out like a disabled button.
  let {
    label,
    busyLabel,
    busy,
    disabled,
  }: { label: string; busyLabel: string; busy: boolean; disabled: boolean } = $props()
</script>

<button
  type="submit"
  class={['sketch-button submit w-full', busy && 'busy']}
  disabled={disabled || busy}
  aria-busy={busy}
>
  {#if busy}
    {busyLabel}<span class="dots" aria-hidden="true"><span>.</span><span>.</span><span>.</span></span>
  {:else}
    {label}
  {/if}
</button>

<style>
  /* One stripe period (24px across the stripes) measured along a 45° line, so the tile repeats seamlessly. */
  .submit.busy:disabled {
    --stripe: 33.941px;
    cursor: progress;
    filter: none;
    opacity: 1;
    transform: translateY(3px);
    box-shadow:
      inset 0 2px 0 rgba(255, 255, 255, 0.35),
      0 0 0 var(--sb-ring-deep);
    background-image:
      repeating-linear-gradient(-45deg, rgba(255, 255, 255, 0.2) 0 12px, transparent 12px 24px),
      linear-gradient(#949afb, var(--sb-ring));
    background-size:
      var(--stripe) var(--stripe),
      auto;
    animation: stripes 0.7s linear infinite;
  }
  .dots span {
    display: inline-block;
    animation: hop 1s ease-in-out infinite;
  }
  .dots span:nth-child(2) {
    animation-delay: 0.15s;
  }
  .dots span:nth-child(3) {
    animation-delay: 0.3s;
  }
  @keyframes stripes {
    to {
      background-position:
        var(--stripe) 0,
        0 0;
    }
  }
  @keyframes hop {
    0%,
    60%,
    100% {
      transform: translateY(0);
    }
    30% {
      transform: translateY(-4px);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .submit.busy:disabled,
    .dots span {
      animation: none;
    }
  }
</style>
