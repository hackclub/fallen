<script lang="ts">
  import { untrack } from 'svelte'
  import { fade } from 'svelte/transition'
  import { shared } from '@/lib/shared.svelte'
  import { petState } from '@/lib/pet.svelte'
  import { closeTour, introHeard, openTour, tour } from '@/lib/tour.svelte'

  // The onboarding, over whatever page is open. With `greet` it opens by itself until it is finished (picking a pet
  // finishes it), and cannot be put off: there is nothing to do here before it. Leaving halfway picks up from what the
  // server knows: back at the pet if the project was made, at the project question if the intro was heard, else from the
  // start. In development Shift+L plays it any time and Escape closes it. The dialog is imported on first use, so
  // pages never download it otherwise. Where it is lives in lib/tour.svelte.ts, so it carries on across the visits
  // it makes.
  let { greet = false }: { greet?: boolean } = $props()

  const user = $derived(shared().auth.user)
  const setup = $derived(shared().setup)
  const name = $derived(user?.display_name.split(' ')[0] ?? 'there')
  const showing = $derived(tour.open && !tour.steppedAside)
  // `picked` covers the moment between choosing a pet and the server saying so.
  // Closed by hand in development, so it does not reopen straight away.
  let held = $state(false)
  const due = $derived(greet && setup?.step === 'onboarding' && !petState.picked && !held)

  $effect(() => {
    if (!due || tour.open) return
    untrack(() => {
      const onboarding = setup?.step === 'onboarding' ? setup : null
      const heard = user && introHeard(user.id)
      // Someone who joined a team has a project already, but hasn't heard the intro the way its owner had.
      if (onboarding?.joined_with) openTour(heard ? 'joined' : 'hi')
      else openTour(onboarding?.project ? 'made' : heard ? 'idea' : 'hi')
    })
  })

  // The desktop pet stays out of sight while the onboarding is showing it as the talking egg.
  $effect(() => {
    petState.onboarding = tour.open
  })
  const load = () => import('./Onboarding.svelte')
  // The scene's own exit runs for 0.25s; let it finish before the overlay fades.
  const SCENE_EXIT_MS = 250

  function onkeydown(event: KeyboardEvent) {
    const target = event.target as HTMLElement | null
    if (target?.isContentEditable || (target && /^(input|textarea|select)$/i.test(target.tagName))) return
    if (!import.meta.env.DEV) return
    if (event.key === 'Escape' && showing) {
      held = true
      closeTour()
      return
    }
    if (event.code !== 'KeyL' || !event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return
    event.preventDefault()
    held = true
    if (tour.open) closeTour()
    else openTour()
  }

  // Layouts put their content in stacking contexts; on <body> the overlay sits above all of it.
  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }

  function close() {
    setTimeout(closeTour, SCENE_EXIT_MS)
  }
</script>

<svelte:window {onkeydown} />

{#if showing}
  <!-- See-through and click-through while the spotlight is up: it draws its own dark layer, with a window in it. -->
  <div
    class={[
      'fixed inset-0 z-50 transition-colors duration-300',
      tour.spotlight ? 'pointer-events-none bg-transparent' : 'bg-black/45',
    ]}
    transition:fade={{ duration: 200 }}
    {@attach portal}
  >
    {#await load() then { default: Onboarding }}
      <Onboarding {name} start={tour.start} onclose={close} />
    {/await}
  </div>
{/if}
