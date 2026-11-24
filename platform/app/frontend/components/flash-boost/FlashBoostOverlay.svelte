<script lang="ts" module>
  export interface Boost {
    starts_at: string
    ends_at: string
    lulu_factor: number
    sami_step: number
  }

  // Whether the person has been through the dialog, here or on an earlier visit: Home's gold (FlashBoostBanner)
  // waits for it.
  export const announced = $state({ done: false })
</script>

<script lang="ts">
  import { fade } from 'svelte/transition'
  import { chunk } from '@/lib/chunks'
  import { shared } from '@/lib/shared.svelte'
  import { tour } from '@/lib/tour.svelte'

  // Announces a flash event (FlashBoost) on Home while it runs and never after, once per person in each browser (every
  // visit in development), once the onboarding and welcome back are out of the way: straight after them if they're on
  // this visit. Never for an egg, nor while impersonating, which would mark it seen for them. The dialog is imported
  // only when it shows. `multiplier` is the person's own, before the boost.
  let { boost, multiplier }: { boost?: Boost | null; multiplier?: number } = $props()

  const user = $derived(shared().auth.user)
  const setup = $derived(shared().setup)
  const key = $derived(boost && user ? `fallen:flash-boost:${user.id}:${boost.starts_at}` : '')
  let open = $state(false)
  // Decided once per visit to Home; `waited` when something else was showing first.
  let decided = false
  let waited = false
  // Room for the welcome back to fade out before this fades in.
  const AFTER_OTHER_MS = 600

  $effect(() => {
    if (decided) return
    announced.done = false
    // Never once it's over, even on a page loaded before the end.
    if (!boost || Date.now() >= new Date(boost.ends_at).getTime()) return
    if (!user?.pet || setup || tour.open) return void (waited = true)
    decided = true
    // Eggs skip it, so it doesn't show them their pet before they hatch it; the notice and the boost are still theirs.
    if (shared().impersonation || user.pet_form === 0) return void (announced.done = true)
    let due = true
    if (!import.meta.env.DEV) {
      try {
        due = localStorage.getItem(key) !== '1'
      } catch {
        // Shown, as if never seen.
      }
    }
    if (!due) return void (announced.done = true)
    if (waited) setTimeout(() => (open = true), AFTER_OTHER_MS)
    else open = true
  })

  const load = () => chunk(import('./FlashBoost.svelte'))
  // The scene's own exit runs for 0.25s; let it finish before the overlay fades.
  const SCENE_EXIT_MS = 250

  function close() {
    try {
      localStorage.setItem(key, '1')
    } catch {
      // Shows again next visit; nothing else to do.
    }
    setTimeout(() => {
      open = false
      announced.done = true
    }, SCENE_EXIT_MS)
  }

  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

{#if open && boost && user?.pet}
  <div class="fixed inset-0 z-50 bg-black/45" transition:fade={{ duration: 200 }} {@attach portal}>
    {#await load() then { default: FlashBoost }}
      <FlashBoost pet={user.pet} form={user.pet_form} {boost} multiplier={multiplier ?? 1} onclose={close} />
    {/await}
  </div>
{/if}
