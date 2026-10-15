<script lang="ts">
  // The glare and the bar of light over a `holo-card` (lib/holo.ts sets where they are). Goes last inside the card;
  // rounded to match it.
  let { rounded = 'rounded-xl' }: { rounded?: string } = $props()
</script>

<div class="pointer-events-none absolute inset-0 overflow-hidden {rounded}" aria-hidden="true">
  <div class="glare"></div>
  <div class="shine"></div>
</div>

<style>
  /* a soft white glow centred on the card's top edge, opposite the cursor */
  .glare {
    position: absolute;
    top: -100%;
    left: -100%;
    width: 200%;
    height: 200%;
    background-image: radial-gradient(white, transparent 100%);
    transform: translateX(var(--glare-x, 0%));
    opacity: var(--glare-opacity, 0);
    transition:
      transform var(--holo-ease),
      opacity var(--holo-ease);
  }

  /* one diagonal bar of light, its edges softened in the gradient itself rather than by a blur filter, so moving it
     never re-rasterises a blur */
  .shine {
    position: absolute;
    top: -50%;
    left: 0;
    width: 200%;
    height: 200%;
    background-image: linear-gradient(
      to right bottom,
      transparent calc(47.5% - 4px),
      white calc(47.5% + 4px),
      white calc(52.5% - 4px),
      transparent calc(52.5% + 4px)
    );
    opacity: 0.1;
    transform: translateX(var(--shine-x, -100%));
    transition: transform var(--holo-ease);
  }
</style>
