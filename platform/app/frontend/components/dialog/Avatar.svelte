<script module lang="ts">
  import type { Character } from './types'

  // The pose shown for an emotion, falling back to the character's default.
  export function poseKey(character: Character, emotion?: string) {
    return emotion && character.avatars[emotion]
      ? emotion
      : (character.defaultEmotion ?? Object.keys(character.avatars)[0])
  }
</script>

<script lang="ts">
  import { u } from './geometry'
  import { enter, exit, styler } from './motion'

  type Props = {
    character: Character
    emotion?: string
    talking: boolean
    // In the phone layout it stands in the flow, on top of the bubble, instead of at the scene's corner.
    compact?: boolean
  }

  let { character, emotion, talking, compact = false }: Props = $props()

  const key = $derived(poseKey(character, emotion))
  const spec = $derived(character.avatars[key])

  // Squash-and-stretch from the feet while words are appearing.
  function squash(el: HTMLElement) {
    const s = styler(el)
    if (talking) {
      s.animate(
        { scaleY: [1, 1.03, 1], scaleX: [1, 0.99, 1] },
        { duration: 0.3, ease: 'easeInOut', repeat: Infinity },
      )
    } else {
      s.animate({ scaleY: 1, scaleX: 1 }, { type: 'spring', stiffness: 300, damping: 18 })
    }
    return () => s.stop()
  }

  // AnimatePresence initial={false}: the first pose is just there, later ones pop in.
  let poseMounted = false
  function pose(el: HTMLElement) {
    const from = poseMounted ? { opacity: 0, scale: 0.9, y: 12 } : false
    poseMounted = true
    return enter(from, { opacity: 1, scale: 1, y: 0 }, { type: 'spring', stiffness: 420, damping: 20 })(el)
  }
</script>

{#if spec}
  <!-- Click-through: the character overlaps the bubble and any panel below it. -->
  <div
    class={['pointer-events-none z-10', compact ? 'relative shrink-0' : 'absolute bottom-0 left-0']}
    style:width={u(spec.width)}
    style:height={u(spec.height)}
    style:transform-origin="50% 100%"
    {@attach enter(
      { y: 80, opacity: 0, scale: 0.9 },
      { y: 0, opacity: 1, scale: 1 },
      { type: 'spring', stiffness: 260, damping: 22, mass: 1.1 },
    )}
  >
    <div
      class="size-full"
      {@attach (el) => {
        const s = styler(el)
        s.animate(
          { y: [0, -7, 0], rotate: [0, 0.7, 0, -0.7, 0] },
          { duration: 4.4, ease: 'easeInOut', repeat: Infinity },
        )
        return () => s.stop()
      }}
    >
      <div class="size-full" style:transform-origin="50% 100%" {@attach squash}>
        {#key key}
          <div
            class="absolute"
            style:left={u(spec.offsetX ?? 0)}
            style:top={u(spec.offsetY ?? 0)}
            style:width={u(spec.width)}
            style:height={u(spec.height)}
            style:transform-origin="50% 100%"
            {@attach pose}
            out:exit={{
              target: { opacity: 0, scale: 0.94, y: 6 },
              transition: { duration: 0.12 },
              duration: 0.12,
            }}
          >
            <img
              src={spec.src}
              alt={character.name}
              class="pointer-events-none absolute inset-0 size-full object-contain select-none"
              draggable="false"
              fetchpriority="high"
              data-dialog-avatar
            />
          </div>
        {/key}
      </div>
    </div>
  </div>
{/if}
