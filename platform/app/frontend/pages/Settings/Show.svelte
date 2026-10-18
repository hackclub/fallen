<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import type { LapseStatus } from '@/components/LapsePicker.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import type { SlackStatus } from '@/components/SlackConnect.svelte'
  import TabbedPanel from '@/components/TabbedPanel.svelte'
  import SolarChat from '@/components/icons/SolarChat.svelte'
  import SolarUser from '@/components/icons/SolarUser.svelte'
  import SolarVideocamera from '@/components/icons/SolarVideocamera.svelte'
  import SolarVolume from '@/components/icons/SolarVolume.svelte'
  import LapseSection from '@/components/settings/LapseSection.svelte'
  import PetSection from '@/components/settings/PetSection.svelte'
  import ProfileSection from '@/components/settings/ProfileSection.svelte'
  import SlackSection from '@/components/settings/SlackSection.svelte'
  import SoundSection from '@/components/settings/SoundSection.svelte'
  import { PET_FORMS } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'

  let { slack, lapse, timezone }: { slack?: SlackStatus; lapse?: LapseStatus; timezone?: string } = $props()

  const user = $derived(shared().auth.user)
  const pet = $derived(user?.pet ?? null)

  type Section = 'profile' | 'slack' | 'lapse' | 'pet' | 'sound'
  // The pet's tab only once there is a pet, picked during onboarding.
  const sections = $derived([
    { id: 'profile' as const, label: 'Profile', icon: profileIcon },
    { id: 'slack' as const, label: 'Slack', icon: slackIcon },
    ...(lapse?.configured ? [{ id: 'lapse' as const, label: 'Lapse', icon: lapseIcon }] : []),
    ...(pet ? [{ id: 'pet' as const, label: 'Pet', icon: petIcon }] : []),
    { id: 'sound' as const, label: 'Sound', icon: soundIcon },
  ])
  let current = $state<Section>('profile')
</script>

{#snippet profileIcon()}<SolarUser size={24} />{/snippet}
{#snippet slackIcon()}<SolarChat size={24} />{/snippet}
{#snippet lapseIcon()}<SolarVideocamera size={24} />{/snippet}
{#snippet soundIcon()}<SolarVolume size={24} />{/snippet}
{#snippet petIcon()}
  {#if pet && user}<img src={PET_FORMS[pet][user.pet_form]} alt="" class="size-6 object-contain" />{/if}
{/snippet}

<svelte:head><title>Settings · Fallen</title></svelte:head>

<PageTitle title="Settings" />

<TabbedPanel items={sections} label="Settings" bind:current panelClass="divide-y divide-white/10">
  {#snippet panel(id)}
    <h2 class="px-5 pt-5 pb-4 font-display text-3xl text-white md:px-6">
      {sections.find((s) => s.id === id)?.label}
    </h2>
    {#if id === 'profile' && user}
      <ProfileSection {user} {timezone} />
    {:else if id === 'slack'}
      <SlackSection {slack} />
    {:else if id === 'lapse' && lapse}
      <LapseSection {lapse} />
    {:else if id === 'pet' && pet && user}
      <PetSection {user} {pet} />
    {:else if id === 'sound'}
      <SoundSection />
    {/if}
  {/snippet}
  {#snippet after(id)}
    {#if id === 'pet' || id === 'sound'}
      <p class="mt-3 px-1 font-outfit text-xs text-sky-ice/50">Saved in this browser.</p>
    {/if}
  {/snippet}
</TabbedPanel>
