<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import AvatarStack from '@/components/team/AvatarStack.svelte'
  import { formatMinutes } from '@/lib/format'
  import { shared } from '@/lib/shared.svelte'
  import * as sfx from '@/lib/sfx'
  import { CREDIT_RULE, type TeamStatus, type Teammate } from '@/lib/team'
  import { invite as inviteRoute, projectTeammate } from '@/routes'
  import type { Project } from '@/types'

  // Who is building the project, on its page: each person with what they have logged here, the invites still
  // waiting, and leaving or taking someone off. A project with nobody else on it shrinks to one line asking whether
  // anyone else is building it.
  let {
    project,
    team,
    can,
    onInvite,
  }: {
    project: Project
    team: TeamStatus
    can: { invite: boolean; leave: boolean; remove_teammate: boolean }
    onInvite: () => void
  } = $props()

  const me = $derived(shared().auth.user?.id)
  const solo = $derived(team.people.length === 1 && !team.invites?.length)
  const owner = $derived(team.people[0])
  const successor = $derived(team.people[1])

  function remove(person: Teammate) {
    const leaving = person.id === me
    const message = !leaving
      ? `Take ${person.name} off the team? Their journals stay on ${project.title} and still count for them.`
      : person.owner
        ? `Leave ${project.title}? ${successor?.name} becomes its owner. Your journals stay on it and still count for you.`
        : `Leave ${project.title}? Your journals stay on it and still count for you.`
    if (!confirm(message)) return
    router.delete(projectTeammate({ projectId: project.id, id: person.id }).url, { preserveScroll: true })
  }

  function cancel(id: string, name: string) {
    if (!confirm(`Cancel ${name}'s invite?`)) return
    router.delete(inviteRoute(id).url, { preserveScroll: true })
  }
</script>

{#if solo}
  {#if can.invite}
    <button
      type="button"
      onclick={() => {
        sfx.select()
        onInvite()
      }}
      class="glass setting-row w-full cursor-pointer overflow-hidden text-left"
    >
      <AvatarStack people={team.people} size="size-12" />
      <span class="min-w-0 flex-1 basis-56">
        <span class="block font-montserrat text-lg font-semibold tracking-[-0.02em] text-white"
          >Building this with friends?</span
        >
        <span class="mt-0.5 block font-outfit text-sm text-sky-ice/60"
          >Invite up to {team.max - 1} teammates. Each of you journals your own hours and keeps your own XP.</span
        >
      </span>
      <span class="pill-glass h-11 text-base max-sm:hidden">Invite</span>
    </button>
  {/if}
{:else}
  <section class="glass" aria-labelledby="team-heading">
    <div class="flex flex-wrap items-center justify-between gap-3 px-5 pt-5 pb-3 md:px-6">
      <h2 id="team-heading" class="flex items-center gap-3 font-display text-3xl text-white">
        Team <span class="chip">{team.people.length} of {team.max}</span>
      </h2>
      {#if can.invite && (team.open_seats ?? 0) > 0}
        <button
          type="button"
          class="pill-glass h-10 text-sm"
          onclick={() => {
            sfx.select()
            onInvite()
          }}>+ Invite</button
        >
      {:else if can.invite}
        <button type="button" class="pill-glass h-10 text-sm" onclick={onInvite}>Invites</button>
      {/if}
    </div>

    <ul class="divide-y divide-white/10 border-t border-white/10">
      {#each team.people as person (person.id)}
        <li class="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-3 md:px-6">
          <img
            src={person.avatar}
            alt=""
            class="size-10 shrink-0 rounded-full bg-sky-night object-cover ring-2 ring-cream/60"
          />
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap items-center gap-2 font-montserrat font-semibold text-white">
              <span class="truncate">{person.name}</span>
              {#if person.id === me}<span class="chip">You</span>{/if}
              {#if person.owner}<span class="chip bg-saffron/20! text-saffron!">Owner</span>{/if}
            </p>
            <p class="font-outfit text-sm text-sky-ice/60">
              {#if person.journals === 0}
                No journals here yet
              {:else}
                {formatMinutes(person.minutes)} over {person.journals}
                {person.journals === 1 ? 'journal' : 'journals'}
              {/if}
            </p>
          </div>
          {#if person.id === me && can.leave}
            <button
              type="button"
              class="font-outfit text-sm text-sky-ice/60 underline-offset-2 hover:text-red-300 hover:underline"
              onclick={() => remove(person)}>Leave</button
            >
          {:else if person.id !== me && !person.owner && can.remove_teammate}
            <button
              type="button"
              class="font-outfit text-sm text-sky-ice/60 underline-offset-2 hover:text-red-300 hover:underline"
              onclick={() => remove(person)}>Remove</button
            >
          {/if}
        </li>
      {/each}
      {#each team.invites ?? [] as pending (pending.id)}
        <li class="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-3 md:px-6">
          <img
            src={pending.invitee.avatar}
            alt=""
            class="size-10 shrink-0 rounded-full bg-sky-night object-cover opacity-50 ring-2 ring-white/20 ring-dashed"
          />
          <div class="min-w-0 flex-1">
            <p class="truncate font-montserrat font-semibold text-white/70">{pending.invitee.name}</p>
            <p class="font-outfit text-sm text-sky-ice/50">Invited, hasn't answered yet</p>
          </div>
          <button
            type="button"
            class="font-outfit text-sm text-sky-ice/60 underline-offset-2 hover:text-red-300 hover:underline"
            onclick={() => cancel(pending.id, pending.invitee.name)}>Cancel invite</button
          >
        </li>
      {/each}
    </ul>

    <p class="border-t border-white/10 px-5 py-3 font-outfit text-xs text-sky-ice/50 md:px-6">
      {CREDIT_RULE}
      {#if owner && owner.id !== me}Only {owner.name}, the owner, can take people off it.{/if}
    </p>
  </section>
{/if}
