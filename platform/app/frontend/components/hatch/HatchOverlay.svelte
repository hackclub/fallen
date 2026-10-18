<script lang="ts">
  import { onMount } from 'svelte'
  import { hatch, petState } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'

  // Plays the hatch when something asks for it (DesktopPet, when the egg becomes its first form, or ?hatch below). The
  // scene is imported on first use. In development Shift+K plays it any time without changing anything, and Shift+T
  // plays the teaser: one crack and then it just rattles, for recording a clip. Shift+E plays the teaser with the
  // onboarding's egg, from before a pet is picked.
  const user = $derived(shared().auth.user)

  // ?hatch is the "crack it" button in the Slack message sent when the first journal from Slack hatches the egg
  // (EggCrackingJob). The egg has hatched by then, so this replays the hatch for them.
  onMount(() => {
    const url = new URL(location.href)
    if (!url.searchParams.has('hatch')) return
    url.searchParams.delete('hatch')
    history.replaceState(history.state, '', url.pathname + url.search + url.hash)
    if (user?.pet && user.pet_form > 0) hatch(user.pet)
  })

  function onkeydown(event: KeyboardEvent) {
    if (!import.meta.env.DEV || petState.hatching) return
    const target = event.target as HTMLElement | null
    if (target?.isContentEditable || (target && /^(input|textarea|select)$/i.test(target.tagName))) return
    if (!event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return
    if (event.code !== 'KeyK' && event.code !== 'KeyT' && event.code !== 'KeyE') return
    event.preventDefault()
    if (event.code === 'KeyE') hatch('egg', { teaser: true })
    else hatch(petState.picked ?? user?.pet ?? 'lulu', { teaser: event.code === 'KeyT' })
  }
</script>

<svelte:window {onkeydown} />

{#if petState.hatching}
  {#await import('./EggHatch.svelte') then { default: EggHatch }}
    <EggHatch
      pet={petState.hatching.pet}
      teaser={petState.hatching.teaser}
      onclose={petState.hatching.done}
    />
  {/await}
{/if}
