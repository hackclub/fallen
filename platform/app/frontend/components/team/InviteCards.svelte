<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import AvatarStack from '@/components/team/AvatarStack.svelte'
  import * as sfx from '@/lib/sfx'
  import { acceptInvite, invite as inviteRoute } from '@/routes'
  import type { ProjectInvite } from '@/types'
  import defaultBanner from '@/assets/hero/default-banner.jpg'

  // Invites to someone else's project, on top of Home and Projects until they're answered, so one sent while the
  // person was away is the first thing they see. The Slack DM points at the same invite.
  let { invites }: { invites: ProjectInvite[] } = $props()

  let busy = $state<string | null>(null)

  function answer(invite: ProjectInvite, join: boolean) {
    sfx.select()
    busy = invite.id
    const options = { preserveScroll: true, onFinish: () => (busy = null) }
    if (join) router.post(acceptInvite(invite.id).url, {}, options)
    else router.delete(inviteRoute(invite.id).url, options)
  }
</script>

{#if invites.length}
  <ul class="space-y-3" aria-label="Team invites">
    {#each invites as invite (invite.id)}
      <li class="glass flex flex-wrap items-center gap-x-5 gap-y-3 overflow-hidden pr-5 md:pr-6">
        <img
          src={invite.project.banner_url ?? defaultBanner}
          alt=""
          class="h-24 w-28 shrink-0 object-cover max-sm:h-20 max-sm:w-20"
        />
        <div class="min-w-0 flex-1 basis-56 py-3">
          <p class="font-outfit text-sm text-sky-ice/70">
            <img src={invite.inviter.avatar} alt="" class="mr-1 inline size-5 rounded-full align-[-5px]" />
            <strong class="font-semibold text-cream">{invite.inviter.name}</strong> invited you to build
          </p>
          <p class="mt-0.5 truncate font-montserrat text-xl font-semibold tracking-[-0.02em] text-white">
            {invite.project.title}
          </p>
          <p class="mt-1 flex items-center gap-2 font-outfit text-xs text-sky-ice/60">
            <AvatarStack people={invite.project.teammates} size="size-5" />
            You'd journal your own hours and keep your own XP.
          </p>
        </div>
        <div class="flex items-center gap-3 pb-3 sm:pb-0">
          <button
            type="button"
            class="font-outfit text-sm text-sky-ice/60 underline hover:text-white"
            disabled={busy === invite.id}
            onclick={() => answer(invite, false)}>Decline</button
          >
          <button
            type="button"
            class="pill-cream h-11 text-base"
            disabled={busy === invite.id}
            onclick={() => answer(invite, true)}>Join the team</button
          >
        </div>
      </li>
    {/each}
  </ul>
{/if}
