<script lang="ts">
  import { hatch, petState } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'

  // Plays the hatch when something asks for it (DesktopPet, when the egg becomes its first form). The scene is
  // imported on first use. In development Shift+K plays it any time without changing anything, and Shift+T plays the
  // teaser: one crack and then it just rattles, for recording a clip.
  const user = $derived(shared().auth.user)

  function onkeydown(event: KeyboardEvent) {
    if (!import.meta.env.DEV || petState.hatching) return
    const target = event.target as HTMLElement | null
    if (target?.isContentEditable || (target && /^(input|textarea|select)$/i.test(target.tagName))) return
    if (!event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return
    if (event.code !== 'KeyK' && event.code !== 'KeyT') return
    event.preventDefault()
    hatch(petState.picked ?? user?.pet ?? 'lulu', { teaser: event.code === 'KeyT' })
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
