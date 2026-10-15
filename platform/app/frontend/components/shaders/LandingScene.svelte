<script lang="ts">
  // The landing page's moving background: one WebGL canvas drawing the layers in order. Each layer (particles.ts,
  // shards.ts) owns its points, shaders and how it follows the cursor; webgl.ts has the shared plumbing. Both scenes
  // are fixed to the viewport: the hero scene is particles and shards behind the sections, plus film grain over
  // everything; the dust scene is a fainter, sparser field of particles in front of them, so a few drift over every
  // section. Imported dynamically from the page so it starts after the page has painted.
  import { onMount } from 'svelte'
  import Grain from './Grain.svelte'
  import { clamp, perspective, spring, type Layer, type View } from './webgl'
  import { createParticles } from './particles'
  import { createShards } from './shards'

  let { scene = 'hero' }: { scene?: 'hero' | 'dust' } = $props()

  const parallax = 0.3 // world units the camera drifts at the edge of the screen; nearer shards move more

  let canvas: HTMLCanvasElement
  let layers: Layer[] = []
  let size = [0, 0] // the drawing buffer size the projection was last built for

  // the camera keeps up with the cursor: stiff, and critically damped (2 * sqrt(stiffness)) so it arrives
  // without overshooting or trailing behind
  const camera = spring(40, 12.6)
  const cameraTarget = [0, 0]

  onMount(() => {
    // transparent so the page shows through; no antialias because point sprites have no hard edges to smooth
    const gl = canvas.getContext('webgl2', { alpha: true, antialias: false, depth: false })
    if (!gl) return // no WebGL2: the page just goes without the effect

    layers =
      scene === 'hero'
        ? [createParticles(gl, { axis: 100 }), createShards(gl, 140)]
        : [createParticles(gl, { axis: 40, brightness: 0.6 })]
    gl.enable(gl.BLEND)

    const view: View = { projection: new Float32Array(16), camera: camera.value }
    let last = performance.now()
    const render = (now: number) => {
      frame = requestAnimationFrame(render)
      // seconds, capped so a stalled frame or a return to the tab doesn't jump everything forward
      const delta = Math.min(Math.max(0, now - last) / 1000, 0.1)
      last = now

      if (!resize(gl, view.projection)) return
      camera.step([cameraTarget[0] * parallax, cameraTarget[1] * parallax], delta)
      gl.clearColor(0, 0, 0, 0)
      gl.clear(gl.COLOR_BUFFER_BIT)
      for (const layer of layers) {
        layer.update(delta)
        layer.draw(view)
      }
    }
    let frame = requestAnimationFrame(render)

    return () => {
      cancelAnimationFrame(frame)
      layers = []
      gl.getExtension('WEBGL_lose_context')?.loseContext() // free the GPU now, not whenever it is collected
    }
  })

  // match the drawing buffer to the canvas's size on screen, in device pixels. False while it has no size.
  function resize(gl: WebGL2RenderingContext, projection: Float32Array) {
    const width = Math.floor(canvas.clientWidth * devicePixelRatio)
    const height = Math.floor(canvas.clientHeight * devicePixelRatio)
    if (!width || !height) return false
    if (size[0] === width && size[1] === height) return true
    size = [width, height]
    canvas.width = width
    canvas.height = height
    gl.viewport(0, 0, width, height)
    perspective(width / height, projection)
    return true
  }

  // the canvas ignores pointer events so the page stays clickable, so the cursor is tracked on the window
  function onPointerMove(event: PointerEvent) {
    const rect = canvas.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    const y = -((event.clientY - rect.top) / rect.height) * 2 + 1
    for (const layer of layers) layer.pointerMove(x, y, rect.width / rect.height)
    cameraTarget[0] = clamp(x, -1, 1)
    cameraTarget[1] = clamp(y, -1, 1)
  }

  function onPointerLeave() {
    for (const layer of layers) layer.pointerLeave()
    cameraTarget[0] = cameraTarget[1] = 0
  }
</script>

<svelte:window onpointermove={onPointerMove} />
<svelte:document onmouseleave={onPointerLeave} />

{#if scene === 'hero'}
  <Grain />
{/if}

<!-- z-1 is under the page's sections (also z-1, but later); the dust's z-2 is over them, under the frame -->
<div class={['pointer-events-none fixed inset-0', scene === 'hero' ? 'z-1' : 'z-2']} aria-hidden="true">
  <canvas bind:this={canvas} class="block h-full w-full"></canvas>
</div>
