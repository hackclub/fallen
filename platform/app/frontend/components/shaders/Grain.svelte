<script lang="ts">
  // Film grain over the whole page: one tile of noise, one grain per CSS pixel, jumped to a random offset a
  // few times a second like film running through a projector. Each grain is white or black at a small alpha, so it
  // lightens or darkens whatever is under it, text included. That is exactly hard-light blending at `strength` opacity
  // without a mix-blend-mode, which would make the browser re-render the whole page beneath it on every resize.
  import { onMount } from 'svelte'
  import { prefersReducedMotion } from 'svelte/motion'
  import { fade } from 'svelte/transition'
  import { cubicOut } from 'svelte/easing'

  const tile = 256 // CSS pixels; big enough that the repeat doesn't show through the noise
  const strength = 0.05
  const fps = 10
  const fadeIn = 2000 // ms, as long as the slowest particles take to appear

  let layer: HTMLDivElement | undefined = $state()
  let src = $state('')

  onMount(() => {
    src = noiseTile()
    const timer = setInterval(() => {
      if (prefersReducedMotion.current) return // a still grain instead of a flickering one
      const [x, y] = [Math.random(), Math.random()].map((r) => Math.floor(r * tile))
      if (layer) layer.style.transform = `translate(${x}px, ${y}px)`
    }, 1000 / fps)
    return () => clearInterval(timer)
  })

  function noiseTile() {
    const canvas = document.createElement('canvas')
    canvas.width = canvas.height = tile
    const context = canvas.getContext('2d')!
    const image = context.createImageData(tile, tile)
    for (let i = 0; i < image.data.length; i += 4) {
      // the average of two samples clusters towards mid grey instead of being harsh salt and pepper
      const grey = (Math.random() + Math.random()) / 2
      const shade = grey > 0.5 ? 255 : 0
      image.data.set([shade, shade, shade, Math.abs(grey * 2 - 1) * strength * 255], i)
    }
    context.putImageData(image, 0, 0)
    return canvas.toDataURL()
  }
</script>

<div class="pointer-events-none fixed inset-0 z-1000 overflow-hidden" aria-hidden="true">
  {#if src}
    <div
      bind:this={layer}
      class="absolute will-change-transform [image-rendering:pixelated]"
      style:inset="-{tile}px"
      style:background-image="url({src})"
      style:background-size="{tile}px {tile}px"
      in:fade={{ duration: fadeIn, easing: cubicOut }}
    ></div>
  {/if}
</div>
