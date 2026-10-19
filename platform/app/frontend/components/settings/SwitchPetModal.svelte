<script lang="ts">
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import { EGGS } from '@/components/onboarding/EggPicker.svelte'
  import HoldButton from '@/components/settings/HoldButton.svelte'
  import type { PetSwitch } from '@/components/settings/PetSection.svelte'
  import { PET_FORMS, PET_NAMES } from '@/lib/pet.svelte'
  import type { User } from '@/types'

  // What switching costs, spelled out before it happens: the other team's rules, what is lost from this one, and
  // how long until switching back is possible. Going ahead takes a hold, so it can't be clicked through.
  let {
    user,
    pet,
    other,
    petSwitch,
    resetsOn,
    onconfirm,
    onClose,
  }: {
    user: User
    pet: string
    other: string
    petSwitch: PetSwitch
    resetsOn: string | null
    onconfirm: () => void
    onClose: () => void
  } = $props()

  const rules = $derived(petSwitch.rules)
  const perks = $derived(EGGS.find((egg) => egg.value === other)?.perks(rules) ?? [])
  const changes = $derived(
    [
      `Your ${user.xp} XP and your pet's stage come with you.`,
      pet === 'sami' && petSwitch.multiplier > 1
        ? `Your ${petSwitch.multiplier}x multiplier goes back to 1x.`
        : null,
      pet === 'lulu' ? `Days journaled this week stop counting toward Lulu's +${rules.lulu_bonus} XP.` : null,
      other === 'sami'
        ? `Sami's weeks run Monday to Sunday, so days missed since Monday use up its freezes.`
        : null,
      `This week's XP counts for Team ${PET_NAMES[other]} in the race.`,
    ].filter((line): line is string => line !== null),
  )

  // The settings panel is a stacking context; on <body> the modal sits above the desktop pet too.
  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<div class="contents" {@attach portal}>
  <OrnateModal
    titleId="switch-pet-title"
    title="Switch to {PET_NAMES[other]}?"
    eyebrow="Switching teams"
    {onClose}
    class="max-w-lg"
  >
    <div class="max-h-[calc(90vh-130px)] overflow-y-auto px-5 pt-2 pb-6 font-outfit md:px-9 md:pb-8">
      <div class="flex items-center justify-center gap-4">
        <figure class="text-center">
          <img src={PET_FORMS[pet][user.pet_form]} alt="" class="mx-auto h-20 object-contain opacity-60" />
          <figcaption class="mt-1 text-sm text-ink-soft">{PET_NAMES[pet]}</figcaption>
        </figure>
        <svg
          viewBox="0 0 24 24"
          class="size-6 shrink-0 text-gold"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          aria-hidden="true"
        >
          <path d="M5 12h14m-5-5 5 5-5 5" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <figure class="text-center">
          <img src={PET_FORMS[other][user.pet_form]} alt="" class="mx-auto h-20 object-contain" />
          <figcaption class="mt-1 text-sm font-semibold text-cream">{PET_NAMES[other]}</figcaption>
        </figure>
      </div>

      <h3 class="mt-6 text-xs font-bold tracking-[0.2em] text-gold/80 uppercase">Team {PET_NAMES[other]}</h3>
      <ul class="mt-2 space-y-1.5 text-sm text-cream">
        {#each perks as perk (perk)}<li class="flex gap-2"><span class="text-gold">+</span>{perk}</li>{/each}
      </ul>

      <h3 class="mt-5 text-xs font-bold tracking-[0.2em] text-gold/80 uppercase">What changes</h3>
      <ul class="mt-2 space-y-1.5 text-sm text-ink-soft">
        {#each changes as change (change)}<li class="flex gap-2"><span>•</span>{change}</li>{/each}
      </ul>

      <p class="mt-5 rounded-xl border border-gold/30 bg-gold/10 px-4 py-3 text-center text-sm text-cream">
        {#if petSwitch.free}
          Switching is free until your second journal. After that you get one switch a week.
        {:else}
          This is your switch for the week. You can't switch back until <strong>{resetsOn}</strong>.
        {/if}
      </p>

      <div class="mt-6 flex flex-col-reverse items-center justify-center gap-3 sm:flex-row">
        <OrnateButton kind="cancel" onclick={onClose} autofocus>Stay with {PET_NAMES[pet]}</OrnateButton>
        <HoldButton label="Hold to switch" done="Switching" seconds={1.5} {onconfirm} />
      </div>
    </div>
  </OrnateModal>
</div>
