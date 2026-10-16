<script module lang="ts">
  import { ARROW, BODY_TEXT, BUBBLE, NAME_TAG, u } from './geometry'
  import { buildWobblePath, WOBBLE_CANVAS } from './wobble'

  const SPRING = { type: 'spring', stiffness: 380, damping: 24 } as const

  // The generator's canvas is padded so the wobble has room to breathe; map its inner rectangle onto the bubble box
  // and let the SVG overflow.
  const scaleX = BUBBLE.width / (WOBBLE_CANVAS.width - 2 * WOBBLE_CANVAS.pad)
  const scaleY = BUBBLE.height / (WOBBLE_CANVAS.height - 2 * WOBBLE_CANVAS.pad)
  const canvasStyle = [
    `left: ${u(-WOBBLE_CANVAS.pad * scaleX)}`,
    `top: ${u(-WOBBLE_CANVAS.pad * scaleY)}`,
    `width: ${u(WOBBLE_CANVAS.width * scaleX)}`,
    `height: ${u(WOBBLE_CANVAS.height * scaleY)}`,
  ].join('; ')
  const initialPath = buildWobblePath(0)

  // The edge morphs at well under one cycle per second, so 30 updates/s is indistinguishable from 60 and halves the
  // raster work: every `d` change re-tessellates and repaints the whole bubble area at device resolution.
  const WOBBLE_INTERVAL_MS = 1000 / 30

  // Body copy reads best on two lines. RevealText reserves layout up front, so the wrap can be measured before the
  // words have animated in: step the type down towards the floor until it fits in two lines. Copy that cannot get
  // there even at the floor goes back to full size and lets `text-wrap: balance` even out its three lines instead.
  const MAX_LINES = 2

  function countLines(box: HTMLElement) {
    let lines = 0
    for (const paragraph of box.querySelectorAll('p')) {
      const tops = new Set(
        [...paragraph.querySelectorAll<HTMLElement>('span.inline-block')].map((span) =>
          Math.round(span.getBoundingClientRect().top),
        ),
      )
      lines += tops.size
    }
    return lines
  }

  const ARROW_PATH =
    'M4.66215 0C-1.44709 0.403369 -0.266408 5.88222 1.08759 8.57122C3.74143 11.5964 9.79652 18.2853 12.7861 20.8399C15.7758 23.3945 18.7979 21.9043 19.9353 20.8399C22.4266 17.9828 28.0593 11.5292 30.6589 8.57122C34.0385 1.84864 29.9007 0.0560002 27.4093 0C19.2853 1.84868 11.1614 1.84868 4.66215 0Z'
</script>

<script lang="ts">
  import { untrack } from 'svelte'
  import { frame, cancelFrame } from 'motion'
  import RevealText from './RevealText.svelte'
  import { enter, exit, prefersReducedMotion, styler } from './motion'
  import type { Character } from './types'

  type Props = {
    character?: Character
    text: string
    revealKey: number
    skipped: boolean
    showArrow: boolean
    onRevealComplete: () => void
  }

  let { character, text, revealKey, skipped, showArrow, onRevealComplete }: Props = $props()

  let path: SVGPathElement
  $effect(() => {
    if (prefersReducedMotion()) return
    let start: number | undefined
    let last = 0
    const tick = ({ timestamp }: { timestamp: number }) => {
      start ??= timestamp
      const time = timestamp - start
      if (time - last < WOBBLE_INTERVAL_MS) return
      last = time
      path.setAttribute('d', buildWobblePath(time / 1000))
    }
    frame.update(tick, true)
    return () => cancelFrame(tick)
  })

  // A small bounce every time a new line lands, so the bubble reads as "speaking" rather than as a static panel
  // whose text changed.
  let inner: HTMLElement
  let first = true
  $effect(() => {
    void revealKey
    if (first) {
      first = false
      return
    }
    styler(inner).animate({ scale: [0.975, 1] }, { type: 'spring', stiffness: 600, damping: 16 })
  })

  let textBox: HTMLElement
  let textSize = $state(BODY_TEXT.fontSize)
  $effect(() => {
    void text
    untrack(fit)
  })
  function fit() {
    const box = textBox
    let candidate = BODY_TEXT.fontSize
    for (;;) {
      box.style.fontSize = u(candidate)
      if (countLines(box) <= MAX_LINES) break
      if (candidate <= BODY_TEXT.minFontSize) {
        candidate = BODY_TEXT.fontSize
        break
      }
      candidate = Math.max(candidate - BODY_TEXT.fontStep, BODY_TEXT.minFontSize)
    }
    box.style.fontSize = u(candidate)
    textSize = candidate
  }

  // The name tag only animates when the speaker changes, not when the bubble first appears.
  let tagMounted = false
  function nameTag(el: HTMLElement) {
    const from = tagMounted ? { scale: 0, rotate: 8, opacity: 0 } : false
    tagMounted = true
    return enter(
      from,
      { scale: 1, rotate: 0, opacity: 1 },
      { type: 'spring', stiffness: 500, damping: 22 },
    )(el)
  }
</script>

<div
  class="pointer-events-auto absolute"
  style:left={u(BUBBLE.left)}
  style:top={u(BUBBLE.top)}
  style:width={u(BUBBLE.width)}
  style:height={u(BUBBLE.height)}
  style:transform-origin="50% 100%"
  {@attach enter(
    { scale: 0.6, y: 60, opacity: 0 },
    { scale: 1, y: 0, opacity: 1 },
    { ...SPRING, delay: 0.1 },
  )}
>
  <div class="relative size-full" bind:this={inner}>
    <!-- Its own compositor layer, so the per-frame repaint stays inside this rectangle instead of invalidating the
         text and background around it. -->
    <svg
      aria-hidden="true"
      class="absolute overflow-visible will-change-transform"
      style={canvasStyle}
      viewBox="0 0 {WOBBLE_CANVAS.width} {WOBBLE_CANVAS.height}"
      preserveAspectRatio="none"
    >
      <path bind:this={path} d={initialPath} fill={BUBBLE.fill} />
    </svg>

    {#if character}
      {#key character.id}
        <div
          class="absolute flex justify-center font-dialog font-medium whitespace-nowrap text-white"
          style:left={u(NAME_TAG.left)}
          style:top={u(NAME_TAG.top)}
          style:min-width={u(NAME_TAG.minWidth)}
          style:height={u(NAME_TAG.height)}
          style:padding={`${u(NAME_TAG.paddingTop)} ${u(NAME_TAG.paddingX)} 0`}
          style:border-radius={u(NAME_TAG.radius)}
          style:font-size={u(NAME_TAG.fontSize)}
          style:line-height={NAME_TAG.lineHeight}
          style:background={character.color ?? NAME_TAG.fill}
          style:transform-origin="20% 100%"
          {@attach nameTag}
          out:exit={{
            target: { scale: 0, rotate: -8, opacity: 0 },
            transition: { duration: 0.15 },
            duration: 0.15,
          }}
        >
          {character.name}
        </div>
      {/key}
    {/if}

    <div class="absolute inset-0 flex flex-col items-center justify-center">
      <div
        bind:this={textBox}
        class="text-center font-dialog font-semibold [word-break:break-word] text-white [text-wrap:balance]"
        style:width={u(BODY_TEXT.width)}
        style:font-size={u(textSize)}
        style:line-height={BODY_TEXT.lineHeight}
      >
        {#key revealKey}
          <div>
            <RevealText {text} {skipped} onComplete={() => onRevealComplete()} />
          </div>
        {/key}
      </div>
    </div>

    {#if showArrow}
      <div
        class="absolute flex items-center justify-center"
        style:right={u(ARROW.right)}
        style:bottom={u(ARROW.bottom)}
        style:width={u(ARROW.width)}
        style:height={u(ARROW.height)}
        {@attach enter(
          { scale: 0, opacity: 0 },
          { scale: 1, opacity: 1 },
          { type: 'spring', stiffness: 520, damping: 18 },
        )}
        out:exit={{ target: { scale: 0, opacity: 0 }, transition: { duration: 0.12 }, duration: 0.12 }}
      >
        <svg
          class="shrink-0 overflow-visible"
          style:width={u(ARROW.pathWidth)}
          style:height={u(ARROW.pathHeight)}
          viewBox="0 0 {ARROW.pathWidth} {ARROW.pathHeight}"
          aria-hidden="true"
          {@attach (el: SVGSVGElement) => {
            const s = styler(el)
            s.set({ rotate: ARROW.rotate })
            s.animate({ x: [0, 3, 0] }, { duration: 0.8, ease: 'easeInOut', repeat: Infinity, delay: 0.3 })
            return () => s.stop()
          }}
        >
          <path d={ARROW_PATH} fill={ARROW.fill} />
        </svg>
      </div>
    {/if}
  </div>
</div>
