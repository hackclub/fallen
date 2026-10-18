<script lang="ts">
  import { onMount } from 'svelte'
  import { hatch, hatchSeen, petState } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'

  // Plays the hatch when something asks for it (DesktopPet, when the egg becomes its first form, or ?hatch below),
  // then for a first hatch the pet's welcome (HatchWelcome). The scenes are imported on first use. In development
  // Shift+K plays the hatch and welcome any time without changing anything, and Shift+T plays the teaser: one crack
  // and then it just rattles, for recording a clip. Shift+E plays the teaser with the onboarding's egg, from before a
  // pet is picked.
  const user = $derived(shared().auth.user)

  // ?hatch is the "crack it" button in the Slack message sent when the first journal from Slack hatches the egg
  // (EggCrackingJob). The egg has hatched by then, so this replays the hatch for them.
  onMount(() => {
    const url = new URL(location.href)
    if (!url.searchParams.has('hatch')) return
    url.searchParams.delete('hatch')
    history.replaceState(history.state, '', url.pathname + url.search + url.hash)
    if (user?.pet && user.pet_form > 0) hatch(user.pet, { welcome: true })
  })

  let welcomeScene: Promise<typeof import('./HatchWelcome.svelte')> | undefined
  const loadWelcome = () => (welcomeScene ??= import('./HatchWelcome.svelte'))
  $effect(() => {
    if (petState.hatching?.welcome) loadWelcome()
  })

  // Where the hatched pet went next: into the welcome, or down into the desktop pet like the end of the onboarding.
  let welcome = $state<{ pet: string; from: DOMRect } | null>(null)
  let hatchClosed = $state(false)

  function handoff(from: DOMRect) {
    const hatching = petState.hatching!
    if (hatching.welcome) {
      welcome = { pet: hatching.pet, from }
      if (!hatching.preview) hatchSeen()
      return true
    }
    if (!document.querySelector('[data-desktop-pet]')) return false
    petState.hatched = from
    return true
  }

  function hatchDone() {
    hatchClosed = true
    if (!welcome) finish()
  }

  function finish() {
    welcome = null
    hatchClosed = false
    petState.hatching?.done()
  }

  function onkeydown(event: KeyboardEvent) {
    if (!import.meta.env.DEV || petState.hatching) return
    const target = event.target as HTMLElement | null
    if (target?.isContentEditable || (target && /^(input|textarea|select)$/i.test(target.tagName))) return
    if (!event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return
    if (event.code !== 'KeyK' && event.code !== 'KeyT' && event.code !== 'KeyE') return
    event.preventDefault()
    if (event.code === 'KeyE') hatch('egg', { teaser: true })
    else if (event.code === 'KeyT') hatch(petState.picked ?? user?.pet ?? 'lulu', { teaser: true })
    else hatch(petState.picked ?? user?.pet ?? 'lulu', { welcome: true, preview: true })
  }
</script>

<svelte:window {onkeydown} />

{#if petState.hatching && !hatchClosed}
  {#await import('./EggHatch.svelte') then { default: EggHatch }}
    <EggHatch pet={petState.hatching.pet} teaser={petState.hatching.teaser} {handoff} onclose={hatchDone} />
  {/await}
{/if}

{#if welcome}
  {#await loadWelcome() then { default: HatchWelcome }}
    <HatchWelcome pet={welcome.pet} from={welcome.from} onclose={finish} />
  {/await}
{/if}
