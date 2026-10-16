<script module lang="ts">
  import { getContext, setContext, type Snippet } from 'svelte'
  import { u } from './geometry'

  // The full-width "strip window" from the onboarding slides: a slanted cyan band with a drifting checkered weave,
  // a white plate with clipped corners, a message on top and controls below. Vertical sizes are design units of the
  // 1920x1080 slide; the corner cuts and side padding are a share of the stage width so the shape keeps its angle and
  // the content never runs into a cut. The band anchors to the stage bottom and grows upward when its content wraps,
  // so its distance to the speech bubble never changes.
  export const STRIP = {
    bottom: 427,
    minHeight: 355,
    plateInset: 10,
    cutWidthPct: (298 / 1920) * 100,
    cutHeightPct: (120 / 1920) * 100, // of the width, to keep the diagonal's angle
    messageTop: 39,
    messageSize: 24,
    messageLineHeight: 1.2,
    paddingBottom: 31, // with the Confirm shell border, lands the band at 355
    controlsTop: 207,
    checkerSize: 100,
    checkerAngle: 10.96,
  }

  export const SPRING = { type: 'spring', stiffness: 210, damping: 24, mass: 1 } as const

  // The controls row staggers its PanelItems in, like motion's delayChildren/staggerChildren.
  const CONTROLS_DELAY = 0.3
  const CONTROLS_STAGGER = 0.07
  const STAGGER = Symbol('strip-stagger')

  export function nextItemDelay() {
    const next = getContext<(() => number) | undefined>(STAGGER)
    return next ? next() : 0
  }

  function provideStagger() {
    let count = 0
    setContext(STAGGER, () => CONTROLS_DELAY + count++ * CONTROLS_STAGGER)
  }
</script>

<script lang="ts">
  import { enter, exit } from './motion'

  type Props = {
    message?: Snippet | string
    children?: Snippet
    // Where the controls start, as a y within the band on the slide (assumes a one-line message). Content that wraps
    // pushes them down and grows the band.
    controlsTop?: number
  }

  let { message, children, controlsTop = STRIP.controlsTop }: Props = $props()

  provideStagger()

  const messageHeight = $derived(message ? STRIP.messageSize * STRIP.messageLineHeight : 0)
  const sidePadding = `${STRIP.cutWidthPct}cqw`
  const cut = STRIP.cutWidthPct
  const cutH = STRIP.cutHeightPct
  const FULL_CLIP = 'inset(0% 0% 0% 0%)'
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="absolute inset-x-0 z-[5]"
  style:bottom={u(STRIP.bottom)}
  style:min-height={u(STRIP.minHeight)}
  {@attach enter({ clipPath: FULL_CLIP, opacity: 1 }, { clipPath: FULL_CLIP, opacity: 1 })}
  out:exit|global={{
    // Shutters closed: top and bottom edges race to the middle, then it is gone.
    target: { clipPath: 'inset(50% 0% 50% 0%)', opacity: 0 },
    transition: {
      clipPath: { duration: 0.26, ease: [0.55, 0, 1, 0.45] },
      opacity: { duration: 0.06, delay: 0.22 },
    },
    duration: 0.28,
  }}
  onclick={(event) => event.stopPropagation()}
>
  <!-- Band: base tone, drifting checker weave, cyan gradient over it. Wider than the stage so the spring's overshoot
       never shows an edge. -->
  <div
    class="absolute inset-y-0 overflow-hidden"
    style:left="-10%"
    style:right="-10%"
    style:background="#01A5FE"
    {@attach enter({ x: '-100%', skewX: -16 }, { x: '0%', skewX: 0 }, SPRING)}
  >
    <div aria-hidden="true" class="absolute" style:inset="-60% -20%" style:rotate="{STRIP.checkerAngle}deg">
      <!-- One extra tile period on each side so the loop never shows a seam. -->
      <div
        class="dlg-checker-drift absolute"
        style:inset="0 {u(-STRIP.checkerSize * 2)}"
        style:background-image="repeating-conic-gradient(#01BBFE 0 25%, transparent 0 50%)"
        style:background-size={`${u(STRIP.checkerSize * 2)} ${u(STRIP.checkerSize * 2)}`}
      ></div>
    </div>
    <div
      aria-hidden="true"
      class="absolute inset-0"
      style:background="linear-gradient(180deg, rgba(1, 206, 242, 0) 0%, rgba(1, 206, 242, 0.7) 100%)"
    ></div>
  </div>

  <!-- Plate: white with the two clipped corners. The shadow lives on the wrapper so the clip does not cut it off. -->
  <div
    class="absolute inset-x-0"
    style:top={u(STRIP.plateInset)}
    style:bottom={u(STRIP.plateInset)}
    style:filter="drop-shadow(0 0 {u(5)} rgba(0, 0, 0, 0.25))"
    style:transform-origin="0% 50%"
    {@attach enter({ scaleX: 0 }, { scaleX: 1 }, { ...SPRING, stiffness: 240, delay: 0.06 })}
  >
    <div
      class="relative size-full overflow-hidden"
      style:background="linear-gradient(180deg, #FFFFFF 0%, #F3F3F3 100%)"
      style:clip-path={`polygon(${cut}cqw 0, 100% 0, 100% calc(100% - ${cutH}cqw), calc(100% - ${cut}cqw) 100%, 0 100%, 0 ${cutH}cqw)`}
    >
      <div
        aria-hidden="true"
        class="absolute inset-y-0 w-[28%]"
        style:background={`linear-gradient(100deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.9) 50%, rgba(255,255,255,0) 100%)`}
        {@attach enter(
          { x: '-60%', opacity: 0, skewX: -18 },
          { x: '160%', opacity: [0, 0.55, 0] },
          { duration: 0.7, delay: 0.3, ease: 'easeOut' },
        )}
      ></div>
    </div>
  </div>

  <div
    class="relative flex flex-col"
    style:padding={`${u(STRIP.messageTop)} ${sidePadding} ${u(STRIP.paddingBottom)}`}
  >
    {#if message}
      <p
        class="m-0 text-center font-dialog font-medium text-black"
        style:font-size={u(STRIP.messageSize)}
        style:line-height={STRIP.messageLineHeight}
        {@attach enter(
          { y: 18, opacity: 0, scale: 0.96 },
          { y: 0, opacity: 1, scale: 1 },
          { type: 'spring', stiffness: 400, damping: 26, delay: 0.24 },
        )}
      >
        {#if typeof message === 'string'}{message}{:else}{@render message()}{/if}
      </p>
    {/if}

    {#if children}
      <div
        class="flex flex-wrap items-start justify-center"
        style:margin-top={u(controlsTop - STRIP.messageTop - messageHeight)}
        style:gap={u(24)}
      >
        {@render children()}
      </div>
    {/if}
  </div>
</div>
