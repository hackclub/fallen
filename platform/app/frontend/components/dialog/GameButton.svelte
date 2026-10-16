<script module lang="ts">
  import { u } from './geometry'

  // The chunky 3D button from the slides, replicated from the Figma "Invite!" button (fallout file, node 4543-23): a
  // 343 x 158 frame with a white stroke outside it and a soft drop shadow, a glossy gradient face 10 shorter than the
  // frame, and the face's hard 10-unit drop shadow forming the bevel it sinks onto when pressed. Every measurement is
  // a share of the frame height, so one `height` reproduces the design at any size. Heights and widths are design
  // units (`--dlg-u`, 1px when unset) like the rest of the dialog.
  export const GAME_BUTTON_DESIGN = {
    height: 158,
    // Drawn outside the frame, as in Figma, so the rendered box is one stroke larger on every side than `height`
    // and `width`.
    shellStroke: 5,
    shellShadowY: 3,
    shellShadowBlur: 10,
    radius: 31,
    bevel: 10,
    faceStroke: 4,
    fontSize: 64,
    // Outside the glyphs.
    textStroke: 4,
    textShadowY: 3,
    // The room either side of "Invite!" (177 wide) in its 343 frame, used when a button hugs its label instead of
    // taking a fixed width.
    paddingX: 83,
  }

  const D = GAME_BUTTON_DESIGN
  // A Figma measurement as its share of the button's height.
  const share = (n: number) => `calc(var(--gb-h) * ${n} / ${D.height})`
  // How far the face has sunk onto the bevel. The spring drives a 0..1 factor, because it cannot interpolate a
  // calc() distance directly.
  const sink = `calc(${share(D.bevel)} * var(--gb-press, 0))`

  export type GameButtonSize = 'lg' | 'md' | 'sm'
  // Frame sizes from the onboarding slides at 85%, without the outside stroke.
  export const GAME_BUTTON_SIZES: Record<GameButtonSize, { height: number; width?: number }> = {
    lg: { height: 88, width: 449 },
    md: { height: 71, width: 201 },
    sm: { height: 64 },
  }

  export type GameButtonColors = {
    faceTop: string
    faceBottom: string
    faceBorder: string
    bevel: string
    // Text outline and drop.
    ink: string
    shell: string
    text: string
  }
  export type GameButtonTone = 'blue' | 'pink'
  export const GAME_BUTTON_TONES: Record<GameButtonTone, GameButtonColors> = {
    blue: {
      faceTop: '#20C7FF',
      faceBottom: '#1CB0F6',
      faceBorder: 'rgba(32, 198, 255, 0.7)',
      bevel: '#2A96D3',
      ink: '#09476E',
      shell: '#FFFFFF',
      text: '#FFFFFF',
    },
    pink: {
      faceTop: '#FF6B99',
      faceBottom: '#FF427D',
      faceBorder: 'rgba(255, 140, 175, 0.7)',
      bevel: '#C92C5D',
      ink: '#6E0F30',
      shell: '#FFFFFF',
      text: '#FFFFFF',
    },
  }

  const SPRING = { type: 'spring', stiffness: 600, damping: 22 }
  const PRESS_SPRING = { type: 'spring', stiffness: 700, damping: 30 }
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'
  import { gestures } from './gestures'

  type Props = {
    children: Snippet
    onclick?: () => void
    size?: GameButtonSize
    // Frame height and width in design units; either overrides the preset.
    height?: number
    width?: number | 'auto'
    tone?: GameButtonTone
    // Per-colour overrides on top of the tone.
    colors?: Partial<GameButtonColors>
    // Held down: the face stays sunk on the bevel. For toggles.
    selected?: boolean
    disabled?: boolean
    autofocus?: boolean
    class?: string
  }

  let {
    children,
    onclick,
    size = 'lg',
    height,
    width,
    tone = 'blue',
    colors: overrides,
    selected = false,
    disabled = false,
    autofocus,
    class: className = '',
  }: Props = $props()

  const preset = $derived(GAME_BUTTON_SIZES[size])
  const frameHeight = $derived(height ?? preset.height)
  const frameWidth = $derived(width === undefined ? preset.width : width === 'auto' ? undefined : width)
  const colors = $derived({ ...GAME_BUTTON_TONES[tone], ...overrides })
  const faceHeight = D.height - D.bevel

  // A light sweeps across the face when the button comes alive, so the eye is drawn to the thing that just became
  // possible. Keyed so a quick disable/enable restarts it instead of being swallowed.
  let sweep = $state(0)
  // svelte-ignore state_referenced_locally
  let wasDisabled = disabled
  $effect(() => {
    if (wasDisabled && !disabled) sweep += 1
    wasDisabled = disabled
  })
</script>

<!-- svelte-ignore a11y_autofocus -->
<button
  type="button"
  onclick={(event) => {
    event.stopPropagation()
    onclick?.()
  }}
  {disabled}
  {autofocus}
  aria-pressed={selected || undefined}
  class="relative flex shrink-0 flex-col outline-none transition-opacity duration-200 select-none disabled:opacity-60 {className}"
  style:--gb-h={u(frameHeight)}
  style:width={frameWidth === undefined ? 'auto' : `calc(${u(frameWidth)} + ${share(2 * D.shellStroke)})`}
  style:max-width="100%"
  style:height={share(D.height + 2 * D.shellStroke)}
  style:padding={share(D.shellStroke)}
  {@attach gestures({
    // The press factor lives here so the shell and the face, plain spans, read the same value; the layout box itself
    // never changes.
    rest: { '--gb-press': selected ? 1 : 0 },
    hover: disabled ? undefined : { scale: 1.035 },
    press: disabled ? undefined : { scale: 0.985, '--gb-press': 1 },
    focus: { scale: 1.035 },
    transition: { ...SPRING, '--gb-press': PRESS_SPRING },
  })}
>
  <!-- The white stroke around face and bevel. It follows the face down, so a pressed button is the face with the
       same border sitting on the bevel, not a face sunk inside a taller frame. -->
  <span
    aria-hidden="true"
    class="absolute inset-x-0 bottom-0"
    style:top={sink}
    style:border-radius={share(D.radius + D.shellStroke)}
    style:background={colors.shell}
    style:box-shadow={`0 ${share(D.shellShadowY)} ${share(D.shellShadowBlur)} rgba(0, 0, 0, 0.25)`}
  ></span>
  <!-- The face's hard drop shadow in Figma: its own shape, one bevel lower. -->
  <span
    aria-hidden="true"
    class="absolute"
    style:left={share(D.shellStroke)}
    style:right={share(D.shellStroke)}
    style:top={share(D.shellStroke + D.bevel)}
    style:height={share(faceHeight)}
    style:border-radius={share(D.radius)}
    style:background={colors.bevel}
  ></span>
  <!-- Figma strokes the glyphs on the outside. A centred CSS stroke of twice the width, painted under the fill,
       leaves the same outline. -->
  <span
    class="relative flex items-center justify-center text-center font-dialog font-semibold whitespace-nowrap"
    style:height={share(faceHeight)}
    style:padding={frameWidth === undefined ? `0 ${share(D.paddingX)}` : '0'}
    style:border-radius={share(D.radius)}
    style:color={colors.text}
    style:background="linear-gradient(180deg, {colors.faceTop} 0%, {colors.faceBottom} 100%)"
    style:border="{share(D.faceStroke)} solid {colors.faceBorder}"
    style:font-size={share(D.fontSize)}
    style:line-height="normal"
    style:-webkit-text-stroke={`${share(2 * D.textStroke)} ${colors.ink}`}
    style:paint-order="stroke fill"
    style:transform="translateY({sink})"
    style:filter={selected ? 'brightness(0.92)' : 'none'}
  >
    <!-- Figma's hard drop is a copy of the stroked glyphs. text-shadow copies only the fill in Chrome, so the outline
         would swallow it; a drop-shadow filter copies what is actually painted. -->
    <span style:filter="drop-shadow(0 {share(D.textShadowY)} 0 {colors.ink})">{@render children()}</span>
    {#if sweep > 0}
      {#key sweep}
        <!-- inset-0 is the padding box, so the clip's corner sits inside the face stroke by one stroke width. -->
        <span aria-hidden="true" class="gb-sweep-clip" style:border-radius={share(D.radius - D.faceStroke)}>
          <span class="gb-sweep" onanimationend={() => (sweep = 0)}></span>
        </span>
      {/key}
    {/if}
  </span>
</button>
