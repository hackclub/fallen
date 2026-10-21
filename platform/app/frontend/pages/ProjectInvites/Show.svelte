<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import JoinCard from '@/components/team/JoinCard.svelte'
  import * as sfx from '@/lib/sfx'
  import { acceptInvite, invite as inviteRoute } from '@/routes'
  import type { ProjectInvite } from '@/types'

  // Where the Slack DM about an invite opens.
  let { invite, full }: { invite: ProjectInvite; full: boolean } = $props()

  let busy = $state(false)

  function answer(yes: boolean) {
    sfx.select()
    busy = true
    const options = { onFinish: () => (busy = false) }
    if (yes) router.post(acceptInvite(invite.id).url, {}, options)
    else router.delete(inviteRoute(invite.id).url, options)
  }
</script>

<svelte:head><title>Join {invite.project.title} · Fallen</title></svelte:head>

<JoinCard
  title={invite.project.title}
  description={invite.project.description}
  bannerUrl={invite.project.banner_url}
  teammates={invite.project.teammates}
  {full}
>
  {#snippet headline()}
    <strong class="font-semibold text-cream">{invite.inviter.name}</strong> invited you to build this with them.
  {/snippet}

  <button
    type="button"
    class="font-outfit text-sm text-sky-ice/60 underline hover:text-white"
    disabled={busy}
    onclick={() => answer(false)}>Decline</button
  >
  {#if !full}
    <button type="button" class="pill-cream h-12 text-lg" disabled={busy} onclick={() => answer(true)}
      >Join the team</button
    >
  {/if}
</JoinCard>
