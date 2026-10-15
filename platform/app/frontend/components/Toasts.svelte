<script lang="ts">
  import { fly } from 'svelte/transition'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import X from '@lucide/svelte/icons/x'
  import { dismiss, toasts } from '@/lib/toasts.svelte'
</script>

<div
  class="pointer-events-none fixed inset-x-0 top-6 z-50 flex flex-col items-center gap-2 px-4"
  role="region"
  aria-label="Notifications"
>
  {#each toasts as t (t.id)}
    <div
      class="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl border-2 bg-paper px-4 py-3 font-outfit text-sm text-ink shadow-[0_12px_40px_-12px_rgba(0,0,0,0.6)] {t.kind ===
      'alert'
        ? 'border-hc-red/60'
        : 'border-paper-rim'}"
      role={t.kind === 'alert' ? 'alert' : 'status'}
      transition:fly={{ y: -8, duration: 200 }}
    >
      {#if t.kind === 'alert'}
        <CircleAlert class="mt-px size-4 shrink-0 text-hc-red" />
      {:else}
        <CircleCheck class="mt-px size-4 shrink-0 text-emerald-600" />
      {/if}
      <span class="flex-1">{t.message}</span>
      <button
        type="button"
        class="shrink-0 cursor-pointer text-ink-soft hover:text-ink"
        aria-label="Dismiss"
        onclick={() => dismiss(t.id)}
      >
        <X class="size-4" />
      </button>
    </div>
  {/each}
</div>
