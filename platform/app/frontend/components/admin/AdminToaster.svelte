<script lang="ts">
  import { Toaster } from 'svelte-sonner'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import Info from '@lucide/svelte/icons/info'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import OctagonX from '@lucide/svelte/icons/octagon-x'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'
  import { adminDark } from '@/lib/adminDark.svelte'
</script>

<!-- shadcn-svelte's Sonner, themed by adminDark instead of mode-watcher. -->
<Toaster
  theme={adminDark.on ? 'dark' : 'light'}
  class="toaster group"
  style="--normal-bg: var(--popover); --normal-text: var(--popover-foreground); --normal-border: var(--border); --border-radius: var(--radius)"
>
  {#snippet successIcon()}<CircleCheck class="size-4" />{/snippet}
  {#snippet errorIcon()}<OctagonX class="size-4 text-destructive" />{/snippet}
  {#snippet warningIcon()}<TriangleAlert class="size-4" />{/snippet}
  {#snippet infoIcon()}<Info class="size-4" />{/snippet}
  {#snippet loadingIcon()}<LoaderCircle class="size-4 animate-spin" />{/snippet}
</Toaster>
