<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import SolarLogout from '@/components/icons/SolarLogout.svelte'
  import { signOut } from '@/routes'
  import type { User } from '@/types'
  import ribbon from '@/assets/shell/nametag.svg'

  let { user, class: className = '' }: { user: User; class?: string } = $props()

  let open = $state(false)
  let root: HTMLElement

  function dismiss(event: MouseEvent) {
    if (open && !root.contains(event.target as Node)) open = false
  }
</script>

<svelte:window onclick={dismiss} onkeydown={(e) => e.key === 'Escape' && (open = false)} />

<div bind:this={root} class="relative {className}">
  {#if open}
    <div
      class="absolute bottom-full left-0 mb-3 min-w-44 rounded-2xl bg-cream p-1.5 font-montserrat text-sm font-semibold text-slate-ink shadow-[0_10px_30px_-10px_rgba(0,0,0,0.6)]"
    >
      <button
        type="button"
        onclick={() => router.visit(signOut())}
        class="flex w-full cursor-pointer items-center gap-2 rounded-xl px-3 py-2 hover:bg-slate-ink/10"
      >
        <SolarLogout size={18} />
        Sign out
      </button>
    </div>
  {/if}

  <!-- Figma "name tag", stretched to fit the name: the ribbon's two ragged ends are windows onto the original SVG and
       a plain cream band (its flat middle, x 65 to 150 and y 6.8 to 46.5) grows between them. The avatar overlaps the left end. -->
  <button
    type="button"
    onclick={() => (open = !open)}
    aria-expanded={open}
    aria-haspopup="menu"
    class="relative flex h-[57px] cursor-pointer items-start rounded-full text-left transition hover:-translate-y-px focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cream"
  >
    <span class="mt-[4px] ml-[5.3px] flex h-[50.4px]">
      <span class="relative w-[65px] shrink-0 overflow-hidden" aria-hidden="true">
        <img src={ribbon} alt="" class="absolute top-0 left-0 max-w-none" />
      </span>
      <span
        class="-mx-px mt-[6.8px] mb-[3.9px] flex max-w-48 items-center bg-cream pl-0.5 font-lora text-base font-medium text-black"
      >
        <span class="truncate">{user.display_name}</span>
      </span>
      <span class="relative w-[59.7px] shrink-0 overflow-hidden" aria-hidden="true">
        <img src={ribbon} alt="" class="absolute top-0 -left-[150px] max-w-none" />
      </span>
    </span>
    <img
      src={user.avatar}
      alt=""
      class="absolute top-0 left-0 h-[56.4px] w-[56.4px] rounded-full bg-sky-night object-cover"
    />
  </button>
</div>
