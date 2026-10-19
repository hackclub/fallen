<script lang="ts">
  import { Toaster } from 'svelte-sonner'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import Info from '@lucide/svelte/icons/info'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'

  // Sonner's own styles are unlayered, so they beat Tailwind's layered utilities: colours go through its variables
  // and the rest needs `!`.
</script>

<Toaster
  position="top-center"
  closeButton
  style="--normal-bg: var(--color-paper); --normal-border: var(--color-paper-rim); --normal-text: var(--color-ink); --border-radius: var(--radius-xl); --width: 24rem"
  toastOptions={{
    classes: {
      toast: 'font-outfit! text-sm! border-2! gap-3! shadow-[0_12px_40px_-12px_rgba(0,0,0,0.6)]!',
      error: 'border-hc-red/60!',
      description: 'text-ink-soft!',
      closeButton: 'bg-paper! border-paper-rim! text-ink-soft! hover:text-ink!',
    },
  }}
>
  {#snippet successIcon()}<CircleCheck class="size-4 text-emerald-600" />{/snippet}
  {#snippet errorIcon()}<CircleAlert class="size-4 text-hc-red" />{/snippet}
  {#snippet warningIcon()}<TriangleAlert class="size-4 text-hc-orange" />{/snippet}
  {#snippet infoIcon()}<Info class="size-4 text-ink-soft" />{/snippet}
  {#snippet loadingIcon()}<LoaderCircle class="size-4 animate-spin text-ink-soft" />{/snippet}
</Toaster>
