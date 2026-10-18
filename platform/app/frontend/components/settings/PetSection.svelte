<script lang="ts">
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import Toggle from '@/components/settings/Toggle.svelte'
  import { FINAL_FORM, PET_FORMS, PET_NAMES } from '@/lib/pet.svelte'
  import { PET_HOME_EVENT, preferences, setPreference } from '@/lib/preferences.svelte'
  import * as sfx from '@/lib/sfx'
  import type { User } from '@/types'

  let { user, pet }: { user: User; pet: string } = $props()

  const petName = $derived(PET_NAMES[pet])
  const stage = $derived(
    user.pet_form === 0
      ? 'Egg'
      : user.pet_form === FINAL_FORM
        ? 'Final form'
        : `Stage ${user.pet_form} of ${FINAL_FORM}`,
  )
  const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches

  // The pet in its card breathes, and hops when poked.
  function breathe(el: HTMLElement) {
    if (reducedMotion()) return
    const a = el.animate(
      { translate: ['0 0', '0 -4px', '0 0'] },
      { duration: 2600, iterations: Infinity, easing: 'ease-in-out' },
    )
    return () => a.cancel()
  }

  function hop(event: MouseEvent) {
    sfx.select()
    if (reducedMotion()) return
    ;(event.currentTarget as HTMLElement).animate(
      { translate: ['0 0', '0 -18px', '0 0'], scale: ['1.1 0.9', '0.95 1.05', '1 1'] },
      { duration: 420, easing: 'cubic-bezier(0.22, 1, 0.36, 1)' },
    )
  }
</script>

<SettingRow title={petName} description={stage}>
  {#snippet lead()}
    <button
      type="button"
      aria-label="Poke {petName}"
      onclick={hop}
      class="grid size-16 cursor-pointer place-items-center rounded-full bg-[radial-gradient(closest-side,rgba(255,255,255,0.18),transparent)] outline-offset-2 outline-cream focus-visible:outline-2"
    >
      <img {@attach breathe} src={PET_FORMS[pet][user.pet_form]} alt="" class="h-14 object-contain" />
    </button>
  {/snippet}
  <div class="w-full max-w-48 basis-40">
    <div class="h-2.5 overflow-hidden rounded-full bg-white/15">
      <div
        class="h-full rounded-full bg-saffron shadow-[0_0_12px_var(--color-saffron)]"
        style:width="{Math.round(user.stage_progress * 100)}%"
      ></div>
    </div>
    <p class="mt-1.5 text-right font-montserrat text-xs font-semibold text-cream/70">
      {user.next_stage_xp != null ? `${user.xp} / ${user.next_stage_xp} XP` : `${user.xp} XP`}
    </p>
  </div>
</SettingRow>
<SettingRow title="Show {petName} on screen" description="{petName} hangs out at the bottom of every page.">
  <Toggle
    label="Show {petName} on screen"
    checked={preferences.pet}
    onchange={(on) => setPreference('pet', on)}
  />
</SettingRow>
<SettingRow title="Call {petName} back" description="Hops back to its spot in the corner.">
  <button
    type="button"
    class="pill-glass"
    disabled={!preferences.pet}
    onclick={() => {
      sfx.select()
      window.dispatchEvent(new Event(PET_HOME_EVENT))
    }}>Call back</button
  >
</SettingRow>
