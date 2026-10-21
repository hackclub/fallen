<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Modal from '@/components/Modal.svelte'
  import { CREDIT_RULE, type TeamStatus } from '@/lib/team'
  import * as sfx from '@/lib/sfx'
  import { invite as inviteRoute, projectInvites, projectJoinLink } from '@/routes'
  import type { Person, Project } from '@/types'

  // Growing the team, two ways: find someone on Fallen by name (they get a Slack DM and a card on their home page),
  // or copy the link and send it anywhere, which also works for someone not signed up yet. Searching goes through the
  // page's optional `people` prop, keeping the URL as it is.
  let {
    project,
    team,
    people,
    onClose,
  }: { project: Project; team: TeamStatus; people: Person[] | undefined; onClose: () => void } = $props()

  let query = $state('')
  let searching = $state(false)
  let sending = $state<string | null>(null)
  let copied = $state(false)
  let input = $state<HTMLInputElement | null>(null)
  let timer: ReturnType<typeof setTimeout> | undefined

  const seats = $derived(team.open_seats ?? 0)
  const results = $derived(query.trim().length >= 2 ? (people ?? []) : [])

  $effect(() => {
    input?.focus()
  })

  function search() {
    clearTimeout(timer)
    if (query.trim().length < 2) return
    timer = setTimeout(() => {
      router.reload({
        only: ['people'],
        data: { people_query: query.trim() },
        preserveUrl: true,
        onStart: () => (searching = true),
        onFinish: () => (searching = false),
      })
    }, 200)
  }

  function send(person: Person) {
    sfx.select()
    sending = person.id
    router.post(
      projectInvites.create(project.id).url,
      { invite: { user_id: person.id } },
      {
        preserveScroll: true,
        preserveState: true,
        onFinish: () => {
          sending = null
          query = ''
          input?.focus()
        },
      },
    )
  }

  async function copy() {
    if (!team.join_url) return
    await navigator.clipboard.writeText(team.join_url)
    sfx.select()
    copied = true
    setTimeout(() => (copied = false), 2000)
  }

  function newLink() {
    if (!confirm('Make a new link? Anyone holding the old one can no longer join with it.')) return
    router.post(projectJoinLink(project.id).url, {}, { preserveScroll: true, preserveState: true })
  }

  function cancel(id: string) {
    router.delete(inviteRoute(id).url, { preserveScroll: true, preserveState: true })
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<Modal titleId="invite-title" title="Invite teammates" {onClose}>
  <div class="max-h-[calc(90vh-130px)] overflow-y-auto px-5 pt-2 pb-6 font-outfit md:px-9 md:pb-8">
    <p class="rounded-2xl bg-paper-well px-4 py-3 text-sm text-ink">
      <strong class="font-semibold">Nothing gets split.</strong>
      {CREDIT_RULE}
    </p>

    {#if seats === 0}
      <p class="mt-5 text-center text-sm text-ink-soft">
        The team is full: {team.max} people at most{team.invites?.length
          ? ', counting invites still waiting'
          : ''}.
      </p>
    {:else}
      <p class="mt-5 mb-1 flex items-baseline justify-between gap-3 text-sm">
        <label for="invite-search" class="text-ink">Find someone on Fallen</label>
        <span class="text-xs text-ink-soft">{seats} {seats === 1 ? 'spot' : 'spots'} left</span>
      </p>
      <div class="relative">
        <input
          id="invite-search"
          bind:this={input}
          bind:value={query}
          oninput={search}
          type="search"
          autocomplete="off"
          placeholder="Their name"
          class="paper-input"
        />
        {#if searching}
          <span
            class="absolute top-1/2 right-3 size-4 -translate-y-1/2 animate-spin rounded-full border-2 border-ink/20 border-t-ink/70"
            aria-hidden="true"
          ></span>
        {/if}
      </div>

      {#if results.length > 0}
        <ul class="mt-2 space-y-1">
          {#each results as person (person.id)}
            <li class="flex items-center gap-3 rounded-xl px-2 py-1.5 hover:bg-ink/5">
              <img
                src={person.avatar}
                alt=""
                class="size-9 shrink-0 rounded-full bg-paper-well object-cover"
              />
              <span class="min-w-0 flex-1 truncate font-semibold text-ink">{person.name}</span>
              <button
                type="button"
                class="game-btn game-btn-blue min-h-9 px-4 text-sm"
                disabled={sending !== null}
                onclick={() => send(person)}>{sending === person.id ? 'Inviting...' : 'Invite'}</button
              >
            </li>
          {/each}
        </ul>
      {:else if query.trim().length >= 2 && !searching && people}
        <p class="mt-2 text-sm text-ink-soft">
          Nobody by that name has finished signing up yet. Send them the link below instead.
        </p>
      {/if}

      {#if team.join_url}
        <p class="mt-6 mb-1 text-sm text-ink">Or send this link, on Slack or anywhere</p>
        <div class="flex gap-2">
          <input
            readonly
            value={team.join_url}
            aria-label="Join link"
            class="paper-input min-w-0 flex-1 font-mono text-xs"
            onfocus={(event) => event.currentTarget.select()}
          />
          <button type="button" class="game-btn game-btn-blue min-h-11 shrink-0 px-5 text-sm" onclick={copy}
            >{copied ? 'Copied!' : 'Copy'}</button
          >
        </div>
        <p class="mt-1.5 flex flex-wrap justify-between gap-2 text-xs text-ink-soft">
          <span>Anyone with it can join, even before they sign up.</span>
          <button type="button" class="underline hover:text-ink" onclick={newLink}>Make a new link</button>
        </p>
      {/if}
    {/if}

    {#if team.invites?.length}
      <p class="mt-6 mb-1 text-sm text-ink">Waiting to hear back</p>
      <ul class="space-y-1">
        {#each team.invites as pending (pending.id)}
          <li class="flex items-center gap-3 px-2 py-1">
            <img
              src={pending.invitee.avatar}
              alt=""
              class="size-8 shrink-0 rounded-full bg-paper-well object-cover opacity-60"
            />
            <span class="min-w-0 flex-1 truncate text-ink">{pending.invitee.name}</span>
            <button
              type="button"
              class="text-xs text-ink-soft underline hover:text-red-700"
              onclick={() => cancel(pending.id)}>Cancel</button
            >
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</Modal>
