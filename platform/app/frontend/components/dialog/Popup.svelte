<script lang="ts">
  import { POPUP, SCENE, u } from './geometry'
  import { enter, exit } from './motion'
  import { gestures } from './gestures'
  import type { DialogContext, PopupSpec } from './types'

  type Props = {
    spec: PopupSpec
    ctx: DialogContext
    onClose: () => void
  }

  let { spec, ctx, onClose }: Props = $props()

  const BUTTON_SPRING = { type: 'spring', stiffness: 500, damping: 20 }
</script>

<!-- Centred in the room above the bubble rather than over it. -->
<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="absolute inset-0 z-20 flex items-center justify-center"
  style:background="rgba(20, 16, 10, 0.45)"
  style:padding-bottom={u(SCENE.height * 0.55)}
  {@attach enter({ opacity: 0 }, { opacity: 1 })}
  out:exit|global={{ target: { opacity: 0 }, transition: { duration: 0.15 }, duration: 0.15 }}
  onclick={(event) => event.stopPropagation()}
>
  <div
    role="dialog"
    aria-modal="true"
    class="relative font-dialog text-white"
    style:width={u(POPUP.width)}
    style:max-width="94%"
    style:border-radius={u(POPUP.radius)}
    style:background={POPUP.fill}
    style:padding={u(POPUP.padding)}
    style:transform-origin="50% 100%"
    {@attach enter(
      { scale: 0.6, y: 60, rotate: -3, opacity: 0 },
      { scale: 1, y: 0, rotate: 0, opacity: 1 },
      { type: 'spring', stiffness: 380, damping: 24 },
    )}
    out:exit|global={{
      target: { scale: 0.85, y: 20, opacity: 0 },
      transition: { duration: 0.14 },
      duration: 0.14,
    }}
  >
    {#if spec.render}
      {@render spec.render({ close: onClose, ctx })}
    {:else}
      <div class="flex flex-col" style:gap={u(22)}>
        {#if spec.title}
          <h2 class="m-0 font-semibold" style:font-size={u(POPUP.titleSize)} style:line-height="1.2">
            {spec.title}
          </h2>
        {/if}
        {#if spec.body}
          <div class="font-medium text-white/85" style:font-size={u(POPUP.bodySize)} style:line-height="1.35">
            {spec.body}
          </div>
        {/if}
        <div class="flex justify-end" style:margin-top={u(8)}>
          <!-- svelte-ignore a11y_autofocus -->
          <button
            type="button"
            autofocus
            class="font-semibold text-white outline-none"
            style:font-size={u(POPUP.buttonSize)}
            style:line-height="1.2"
            style:padding={`${u(14)} ${u(40)}`}
            style:border-radius={u(100)}
            style:background={POPUP.accent}
            {@attach gestures({
              rest: {},
              hover: { scale: 1.05 },
              press: { scale: 0.95 },
              transition: BUTTON_SPRING,
            })}
            onclick={onClose}
          >
            {spec.confirm ?? 'Got it'}
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>
