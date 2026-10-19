<script lang="ts">
  import { Toaster } from 'svelte-sonner'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import Info from '@lucide/svelte/icons/info'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'

  // Toasts look like the nav rail's current page (rail-item): its white glow, brightest at the left edge where a 1px
  // line sits, at the lit page's 0.72, on dark glass so it reads over anything. Sonner's own styles are unlayered, so
  // they beat Tailwind's layered utilities: colours and the close button's corner (top right) go through its
  // variables and the rest needs `!`.
</script>

<Toaster
  position="top-center"
  closeButton
  style="--normal-bg: linear-gradient(to left, rgb(255 255 255 / 0) 0%, rgb(255 255 255 / 0.4) 92%, rgb(255 255 255 / 0.61) 100%), rgb(11 19 64 / 0.82); --normal-border: transparent; --normal-text: white; --border-radius: 4px; --width: 24rem; --toast-close-button-start: unset; --toast-close-button-end: 0; --toast-close-button-transform: translate(35%, -35%)"
  toastOptions={{
    classes: {
      toast:
        'font-montserrat! font-semibold! text-sm! tracking-[-0.01em]! gap-3! border-0! backdrop-blur-md! shadow-[inset_1px_0_0_white,0_12px_40px_-12px_rgba(0,0,0,0.6)]! [&_[data-content]]:drop-shadow-[0_1.5px_4px_rgba(0,0,0,0.35)]',
      error: 'shadow-[inset_1px_0_0_var(--color-hc-red),0_12px_40px_-12px_rgba(0,0,0,0.6)]!',
      description: 'font-outfit! font-normal! text-pale-blue/80!',
      closeButton:
        'size-6! border! border-white/25! bg-sky-night/90! text-white/80! backdrop-blur-md! hover:bg-[#1c2660]! hover:border-white/40! hover:text-white! focus-visible:border-white!',
    },
  }}
>
  {#snippet successIcon()}<CircleCheck class="size-4 text-emerald-300" />{/snippet}
  {#snippet errorIcon()}<CircleAlert class="size-4 text-red-300" />{/snippet}
  {#snippet warningIcon()}<TriangleAlert class="size-4 text-amber-300" />{/snippet}
  {#snippet infoIcon()}<Info class="size-4 text-sky-ice" />{/snippet}
  {#snippet closeIcon()}
    <svg viewBox="0 0 12 12" class="size-2.5" fill="none" stroke="currentColor" stroke-width="2.2">
      <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
    </svg>
  {/snippet}
  {#snippet loadingIcon()}<LoaderCircle class="size-4 animate-spin text-sky-ice" />{/snippet}
</Toaster>
