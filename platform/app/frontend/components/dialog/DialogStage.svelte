<script lang="ts">
  import { untrack, type Snippet } from 'svelte'
  import './dialog.css'
  import { BUBBLE, COMPACT, NAME_TAG, SCENE, u } from './geometry'
  import { Dialog } from './dialog.svelte'
  import { enter, exit, styler } from './motion'
  import Avatar, { poseKey } from './Avatar.svelte'
  import SpeechBubble from './SpeechBubble.svelte'
  import ChoiceBox from './ChoiceBox.svelte'
  import Popup from './Popup.svelte'
  import type { Character, DialogScript, DialogVars } from './types'

  type Props = {
    script: DialogScript
    characters: Character[]
    vars?: DialogVars
    onComplete?: () => void
    // Rendered in place of the scene once the script ends.
    done?: Snippet<[{ restart: () => void }]>
    // Fraction of the stage the scene may take up, width-wise and height-wise. The smaller of the two wins so the
    // picture never crops.
    fit?: { width: number; height: number }
    bottom?: number
    // Horizontal nudge of the scene from centre, in design units.
    offsetX?: number
    class?: string
    children?: Snippet
  }

  let {
    script,
    characters,
    vars,
    onComplete,
    done,
    fit = { width: 0.94, height: 0.5 },
    bottom = 40,
    offsetX = 0,
    class: className = '',
    children,
  }: Props = $props()

  // svelte-ignore state_referenced_locally
  const dialog = new Dialog(script, { characters, vars, onComplete: () => onComplete?.() })
  const node = $derived(dialog.node)
  const phase = $derived(dialog.phase)

  // Keyboard/hover selection, keyed to the node it belongs to so a new line starts back at the first choice.
  let selection = $state({ revealKey: 0, index: 0 })
  const selected = $derived(selection.revealKey === dialog.revealKey ? selection.index : 0)
  function setSelected(index: number | ((s: number) => number)) {
    const current = selected
    selection = { revealKey: dialog.revealKey, index: typeof index === 'function' ? index(current) : index }
  }

  let entered: string | null = null
  $effect(() => {
    const key = `${dialog.state.nodeId}:${dialog.revealKey}`
    if (entered === key) return
    entered = key
    untrack(() => node.onEnter?.(dialog.ctx))
  })

  $effect(() => {
    if (phase !== 'idle' || !node.autoAdvance) return
    const id = window.setTimeout(dialog.advance, node.autoAdvance)
    return () => window.clearTimeout(id)
  })

  // For callers holding the stage with bind:this, such as a skip button outside the script.
  export const nodeId = () => dialog.state.nodeId
  export const jump = (target: string) => dialog.jump(target)

  function restart() {
    entered = null
    dialog.restart()
  }

  function onKey(event: KeyboardEvent) {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return
    const target = event.target as HTMLElement | null
    if (target && /^(input|textarea|select)$/i.test(target.tagName)) return
    const choices = phase === 'idle' ? (node.choices ?? []) : []
    // A panel's own controls are real buttons; leave the keyboard to them.
    if (phase === 'idle' && node.panel) return

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      if (!choices.length) return
      event.preventDefault()
      const step = event.key === 'ArrowDown' ? 1 : -1
      setSelected((s) => (s + step + choices.length) % choices.length)
      return
    }
    if (/^[1-9]$/.test(event.key) && choices.length) {
      const i = Number(event.key) - 1
      if (i < choices.length) dialog.choose(i)
      return
    }
    if (event.key === 'Enter' || event.key === ' ') {
      if (phase === 'popup') return
      event.preventDefault()
      if (choices.length) dialog.choose(selected)
      else dialog.advance()
    }
  }

  const showChoices = $derived(phase === 'idle' && !!node.choices?.length)
  const showPanel = $derived(phase === 'idle' && !!node.panel)
  const showArrow = $derived(phase === 'idle' && !node.choices?.length && !node.panel)
  const showPopup = $derived(phase === 'popup' && !!node.popup)

  // The stage fills the window wherever it is used, so the window stands in for it until it has been measured.
  let stageWidth = $state(typeof window === 'undefined' ? 0 : innerWidth)
  let stageHeight = $state(typeof window === 'undefined' ? 0 : innerHeight)
  const compact = $derived(
    Math.min((fit.width * stageWidth) / SCENE.width, (fit.height * stageHeight) / SCENE.height) <
      COMPACT.belowUnit,
  )

  // One design unit in px (see geometry.ts). Container units keep it tied to the stage rather than the viewport.
  const unit = $derived(
    compact
      ? `${COMPACT.stage}px`
      : `min(calc(${fit.width * 100}cqw / ${SCENE.width}), calc(${fit.height * 100}cqh / ${SCENE.height}))`,
  )

  // In the phone layout the name tag starts just past the character standing on the bubble.
  const tagLeft = $derived.by(() => {
    const character = dialog.character
    if (!character) return COMPACT.bubblePadding.x
    const spec = character.avatars[poseKey(character, dialog.emotion)]
    return (spec?.width ?? 0) * COMPACT.character + COMPACT.tagGap
  })

  // How far up from the stage's bottom edge the bubble starts, for panels that sit above it (EggPicker).
  let compactBubble = $state(0)
  const clear = $derived(
    compact ? `${COMPACT.inset + compactBubble}px` : u(bottom + SCENE.height - BUBBLE.top),
  )
</script>

<svelte:window onkeydown={onKey} />

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="relative overflow-hidden select-none {className}"
  data-dialog-stage
  style:container-type="size"
  style:--dlg-u={unit}
  style:--dlg-clear={clear}
  bind:clientWidth={stageWidth}
  bind:clientHeight={stageHeight}
  onclick={phase === 'done' ? undefined : dialog.advance}
>
  {@render children?.()}

  <!-- Panels sit below the scene (z-10) so the character overlaps them. -->
  {#key dialog.revealKey}
    {#if showPanel}
      {@render node.panel!({ go: dialog.go, ctx: dialog.ctx })}
    {/if}
  {/key}

  {#if phase !== 'done' && compact}
    <!-- The phone layout: the character stands on a full-width bubble pinned to the bottom, with the choices beside
         it, so the bubble never moves as choices come and go. Click-through like the scene below. -->
    <div
      class="pointer-events-none absolute inset-x-0 z-10 mx-auto flex flex-col"
      style:bottom="calc({COMPACT.inset}px + env(safe-area-inset-bottom))"
      style:max-width="{COMPACT.maxWidth}px"
      style:padding-inline="{COMPACT.inset}px"
      out:exit={{
        target: { y: 80, opacity: 0 },
        transition: { duration: 0.25, ease: 'easeIn' },
        duration: 0.25,
      }}
    >
      <div class="flex items-end justify-between" style:gap="{COMPACT.inset}px">
        <div
          style:--dlg-u="{COMPACT.character}px"
          style:margin-bottom="-{COMPACT.overlap}px"
          class="relative z-10"
        >
          {#if dialog.character}
            <Avatar
              character={dialog.character}
              emotion={dialog.emotion}
              talking={phase === 'revealing'}
              compact
            />
          {/if}
        </div>
        {#if showChoices}
          <!-- Lifted clear of the name tag, which pokes up out of the bubble beside the character. -->
          <div
            class="flex min-w-0 justify-end"
            style:--dlg-u="{COMPACT.choices}px"
            style:margin-bottom="{-NAME_TAG.top * COMPACT.nameTag + COMPACT.inset}px"
          >
            {#key dialog.revealKey}
              <ChoiceBox
                choices={node.choices!}
                {selected}
                onSelect={setSelected}
                onChoose={dialog.choose}
                compact
              />
            {/key}
          </div>
        {/if}
      </div>
      <div bind:offsetHeight={compactBubble}>
        <SpeechBubble
          character={dialog.character}
          text={dialog.text}
          revealKey={dialog.revealKey}
          skipped={dialog.skipped}
          {showArrow}
          onRevealComplete={dialog.finishReveal}
          compact
          {tagLeft}
        />
      </div>
    </div>
  {:else if phase !== 'done'}
    <!-- Composited separately from whatever the caller paints behind it, so the floating avatar and wobbling bubble
         never force the (often full-screen) background to repaint. Above panels, so the character stands in front of
         them, and click-through, so its empty area never blocks a panel's controls; the bubble and choice box opt
         back in. -->
    <div
      class="pointer-events-none absolute left-1/2 z-10 will-change-transform"
      style:width={u(SCENE.width)}
      style:height={u(SCENE.height)}
      style:bottom={u(bottom)}
      style:margin-left={u(offsetX)}
      {@attach (el) => styler(el).set({ x: '-50%' })}
      out:exit={{
        target: { y: 80, opacity: 0 },
        transition: { duration: 0.25, ease: 'easeIn' },
        duration: 0.25,
      }}
    >
      <SpeechBubble
        character={dialog.character}
        text={dialog.text}
        revealKey={dialog.revealKey}
        skipped={dialog.skipped}
        {showArrow}
        onRevealComplete={dialog.finishReveal}
      />
      <!-- After the bubble so the character stands in front of it, as in the design. -->
      {#if dialog.character}
        <Avatar character={dialog.character} emotion={dialog.emotion} talking={phase === 'revealing'} />
      {/if}
      {#if showChoices}
        {#key dialog.revealKey}
          <ChoiceBox choices={node.choices!} {selected} onSelect={setSelected} onChoose={dialog.choose} />
        {/key}
      {/if}
    </div>
  {/if}

  {#key dialog.revealKey}
    {#if showPopup}
      <Popup spec={node.popup!} ctx={dialog.ctx} onClose={dialog.closePopup} />
    {/if}
  {/key}

  {#if phase === 'done' && done}
    <div
      class="absolute inset-0"
      {@attach enter(
        { opacity: 0, y: 24 },
        { opacity: 1, y: 0 },
        { type: 'spring', stiffness: 300, damping: 26, delay: 0.2 },
      )}
    >
      {@render done({ restart })}
    </div>
  {/if}
</div>
