<script lang="ts">
  import { CHOICES, u } from './geometry'
  import { enter, exit, styler } from './motion'
  import type { Choice } from './types'

  type Props = {
    choices: Choice[]
    selected: number
    onSelect: (index: number) => void
    onChoose: (index: number) => void
    // In the phone layout it sits in the flow beside the character, sized by the unit the stage gives it.
    compact?: boolean
  }

  let { choices, selected, onSelect, onChoose, compact = false }: Props = $props()

  let pressed = $state<number | null>(null)
  // The highlight tracks the pointer, so it has to clear when the pointer leaves the card entirely; keyboard focus
  // brings it back.
  let active = $state(false)

  // Arrow keys are handled by the stage, not by focus, so the highlight has to come back on its own when someone
  // switches from the mouse to the keyboard.
  function onKeyDown(event: KeyboardEvent) {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') active = true
  }

  function highlight(i: number) {
    let first = true
    return (el: HTMLElement) => {
      const opacity = active && selected === i ? 1 : 0
      if (first) {
        first = false
        styler(el).set({ opacity })
      } else styler(el).animate({ opacity }, { duration: 0.18, ease: 'easeOut' })
    }
  }

  // The nudge is in design units, so it rides a custom property rather than a px `x` that would not scale with the
  // stage.
  function nudge(i: number) {
    let first = true
    return (el: HTMLElement) => {
      const target = { '--dlg-nudge': pressed === i ? -6 : active && selected === i ? 10 : 0 }
      if (first) {
        first = false
        styler(el).set(target)
      } else styler(el).animate(target, { type: 'spring', stiffness: 700, damping: 24, mass: 0.6 })
    }
  }
</script>

<svelte:window onkeydown={onKeyDown} />

<div
  class={['pointer-events-auto flex items-center justify-center', compact ? 'relative min-w-0' : 'absolute']}
  style:right={compact ? undefined : u(CHOICES.right)}
  style:bottom={compact ? undefined : u(CHOICES.bottom)}
  {@attach enter(
    { scale: 0.4, opacity: 0, y: 40, rotate: CHOICES.rotate + 10 },
    { scale: 1, opacity: 1, y: 0, rotate: CHOICES.rotate },
    { type: 'spring', stiffness: 420, damping: 22, mass: 0.9 },
  )}
  out:exit|global={{
    target: { scale: 0.8, opacity: 0, y: 12 },
    transition: { duration: 0.14 },
    duration: 0.14,
  }}
>
  <div
    role="listbox"
    tabindex="-1"
    aria-label="Responses"
    aria-activedescendant="dialog-choice-{selected}"
    class="flex flex-col items-start overflow-hidden"
    onpointerleave={() => {
      active = false
      pressed = null
    }}
    style:width="max-content"
    style:min-width={u(CHOICES.minWidth)}
    style:max-width={compact ? `min(${u(CHOICES.maxWidth)}, 100%)` : u(CHOICES.maxWidth)}
    style:border-radius={u(CHOICES.radius)}
    style:background={CHOICES.fill}
    style:transform-origin="0% 100%"
  >
    {#each choices as choice, i (`${i}-${choice.label}`)}
      <button
        id="dialog-choice-{i}"
        role="option"
        aria-selected={selected === i}
        type="button"
        class="relative flex w-full items-center text-left font-dialog font-semibold [word-break:break-word] text-white outline-none"
        style:padding={`${u(CHOICES.itemPaddingY)} ${u(CHOICES.itemPaddingX)}`}
        style:font-size={u(CHOICES.fontSize)}
        style:line-height={CHOICES.lineHeight}
        style:border-bottom={i < choices.length - 1 ? `max(1px, ${u(1)}) dashed ${CHOICES.divider}` : 'none'}
        {@attach enter(
          { opacity: 0, y: 10 },
          { opacity: 1, y: 0 },
          { type: 'spring', stiffness: 500, damping: 26, delay: i * 0.04 },
        )}
        onpointerenter={() => {
          active = true
          onSelect(i)
        }}
        onpointerdown={() => (pressed = i)}
        onpointerup={() => (pressed = null)}
        onpointerleave={() => {
          if (pressed === i) pressed = null
        }}
        onfocus={() => {
          active = true
          onSelect(i)
        }}
        onblur={() => {
          active = false
          if (pressed === i) pressed = null
        }}
        onclick={(event) => {
          event.stopPropagation()
          onChoose(i)
        }}
      >
        <!-- The dashed divider is a static border on the row so the highlight sliding underneath never nudges it. -->
        <span
          aria-hidden="true"
          class="pointer-events-none absolute inset-0"
          style:background="linear-gradient(to right, {CHOICES.highlight}, transparent)"
          {@attach highlight(i)}
        ></span>
        <span
          class="relative"
          style:transform="translateX(calc(var(--dlg-u, 1px) * var(--dlg-nudge, 0)))"
          {@attach nudge(i)}>{choice.label}</span
        >
      </button>
    {/each}
  </div>
</div>
