<script lang="ts">
  import { Toaster } from 'svelte-sonner'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import Info from '@lucide/svelte/icons/info'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'

  // Sonner's own styles are unlayered, so they beat Tailwind's layered utilities: colours and the close button's corner
  // (top right) go through its variables and the rest needs `!`. The close button is OrnateModal's, navy with a gold rim
  // under the pointer.
</script>

<Toaster
  position="top-center"
  closeButton
  style="--normal-bg: var(--color-paper); --normal-border: var(--color-paper-rim); --normal-text: var(--color-ink); --border-radius: var(--radius-xl); --width: 24rem; --toast-close-button-start: unset; --toast-close-button-end: 0; --toast-close-button-transform: translate(35%, -35%)"
  toastOptions={{
    classes: {
      toast: 'font-outfit! text-sm! border-2! gap-3! shadow-[0_12px_40px_-12px_rgba(0,0,0,0.6)]!',
      error: 'border-hc-red/60!',
      description: 'text-ink-soft!',
      closeButton:
        'size-7! border-2! border-[#2c3680]! bg-[#161d52]! text-light-blue! shadow-[0_4px_12px_-4px_rgba(0,0,0,0.6)]! hover:border-gold! hover:bg-[#161d52]! hover:text-cream! focus-visible:border-gold!',
    },
  }}
>
  {#snippet successIcon()}<CircleCheck class="size-4 text-emerald-600" />{/snippet}
  {#snippet errorIcon()}<CircleAlert class="size-4 text-hc-red" />{/snippet}
  {#snippet warningIcon()}<TriangleAlert class="size-4 text-hc-orange" />{/snippet}
  {#snippet infoIcon()}<Info class="size-4 text-ink-soft" />{/snippet}
  {#snippet closeIcon()}
    <svg viewBox="0 0 12 12" class="size-2.5" fill="none" stroke="currentColor" stroke-width="2.2">
      <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
    </svg>
  {/snippet}
  {#snippet loadingIcon()}<LoaderCircle class="size-4 animate-spin text-ink-soft" />{/snippet}
</Toaster>
