<script module lang="ts">
  // A number that rolls up from zero to the value written in the script, so "[count]83%[/count]" reads 0% → 83%.
  // The digits ease out so the last few ticks are legible, then the figure pops once it lands. The final text sits
  // underneath, invisible, to reserve its width: the line never reflows.
  const DURATION = 0.9
  const EASE: [number, number, number, number] = [0.25, 1, 0.5, 1]
  const POP_SCALE = 1.2
  const POP_SPRING = { type: 'spring', stiffness: 600, damping: 16 } as const

  export const COUNT_DURATION = DURATION
</script>

<script lang="ts">
  import { animate, motionValue } from 'motion'
  import { parseCount } from './textEffects'
  import { prefersReducedMotion } from './motion'

  type Props = {
    text: string
    // Seconds until the word this sits in starts revealing.
    delay: number
    skipped: boolean
    class?: string
    style?: string
  }

  let { text, delay, skipped, class: className = '', style = '' }: Props = $props()

  const spec = $derived(parseCount(text))
  const instant = $derived(skipped || prefersReducedMotion() || !spec)
  const target = $derived(spec?.value ?? 0)
  const decimals = $derived(spec?.decimals ?? 0)

  // svelte-ignore state_referenced_locally
  const value = motionValue(instant ? target : 0)
  const scale = motionValue(1)
  // svelte-ignore state_referenced_locally
  let digits = $state(value.get().toFixed(decimals))
  let scaleNow = $state(1)

  $effect(() => value.on('change', (v) => (digits = v.toFixed(decimals))))
  $effect(() => scale.on('change', (v) => (scaleNow = v)))

  $effect(() => {
    if (instant) {
      value.set(target)
      return
    }
    let pop: { stop: () => void } | undefined
    const roll = animate(value, target, {
      duration: DURATION,
      ease: EASE,
      delay,
      onComplete: () => {
        scale.set(POP_SCALE)
        pop = animate(scale, 1, POP_SPRING)
      },
    })
    return () => {
      roll.stop()
      pop?.stop()
    }
  })
</script>

{#if !spec}{text}{:else}
  <!-- Inline style, not a class: an effect class like .dlg-fx-wobble sets display: inline-block and would flatten
       the two stacked cells. -->
  <span class={className} style="{style}; display: inline-grid"
    ><span class="col-start-1 row-start-1 opacity-0 select-none">{text}</span><span
      aria-hidden="true"
      class="col-start-1 row-start-1"
      style:transform={scaleNow === 1 ? 'none' : `scale(${scaleNow})`}
      style:transform-origin="50% 60%"
      style:text-align={spec.prefix ? 'left' : 'right'}>{spec.prefix}<span>{digits}</span>{spec.suffix}</span
    ></span
  >
{/if}
