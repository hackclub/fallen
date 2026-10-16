<script module lang="ts">
  import type { Component } from 'svelte'

  // Duolingo-style single-choice list: cards with a light grey border and a thicker bottom edge that sinks when
  // pressed, light blue when selected. Sizes are design units (`--dlg-u`, 1px when unset). Styling lives in
  // dialog.css under .dlg-option so the designer can tune it in one place. `icon` is optional; pass a filled
  // single-colour glyph. It inherits the card's text colour, so it turns blue with it.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export type Option = {
    value: string
    label: string
    icon?: Component<any>
    iconProps?: Record<string, unknown>
  }
</script>

<script lang="ts">
  import { u } from './geometry'
  import { enter } from './motion'

  type Props = {
    options: Option[]
    value: string | null
    onchange: (value: string) => void
    // "column" is the Duolingo list. "wrap" lays equal cards in centred rows, for tight spaces like the onboarding
    // strip.
    layout?: 'column' | 'wrap'
    // With "wrap", fix the number of cards per row so a set that would otherwise leave one orphan on the last line
    // reads as a grid instead.
    columns?: number
    // Stagger the cards in on mount. Off by default so it also works as a plain form control.
    animate?: boolean
    class?: string
  }

  let {
    options,
    value,
    onchange,
    layout = 'column',
    columns,
    animate = false,
    class: className = '',
  }: Props = $props()

  const wrap = $derived(layout === 'wrap')
  const cardWidth = $derived(
    wrap && columns !== undefined ? `calc((100% - ${u(12 * (columns - 1))}) / ${columns})` : undefined,
  )
</script>

<div
  role="listbox"
  class="flex w-full {wrap ? 'flex-wrap justify-center' : 'flex-col'} {className}"
  style:gap={u(12)}
  style:max-width={wrap ? (columns ? u(1000) : undefined) : u(600)}
>
  {#each options as option, i (option.value)}
    <!-- The entrance runs on a wrapper so the card's own transform stays free for the CSS press-down; an inline
         transform would override it. -->
    <div
      class={wrap ? '' : 'w-full'}
      style:width={cardWidth}
      {@attach enter(
        animate ? { opacity: 0, y: 14 } : false,
        { opacity: 1, y: 0 },
        { delay: animate ? 0.3 + i * 0.05 : 0, type: 'spring', stiffness: 420, damping: 30 },
      )}
    >
      <button
        type="button"
        role="option"
        aria-selected={value === option.value}
        class="dlg-option {wrap ? 'dlg-option-card' : ''} {cardWidth ? 'dlg-option-grid' : ''}"
        style:padding={wrap ? `${u(11)} ${u(cardWidth ? 20 : 28)}` : `${u(16)} ${u(20)}`}
        style:min-width={wrap ? u(200) : undefined}
        style:width={cardWidth ? '100%' : undefined}
        style:font-size={u(24)}
        style:border-radius={u(16)}
        style:border-width={u(2)}
        onclick={(event) => {
          event.stopPropagation()
          onchange(option.value)
        }}
      >
        {#if option.icon}
          <span aria-hidden="true" class="dlg-option-icon" style:width={u(28)} style:height={u(28)}>
            <option.icon {...option.iconProps} />
          </span>
        {/if}
        <span>{option.label}</span>
      </button>
    </div>
  {/each}
</div>
