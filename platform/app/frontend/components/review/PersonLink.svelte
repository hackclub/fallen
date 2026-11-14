<script lang="ts">
  import { shared } from '@/lib/shared.svelte'
  import { adminUser } from '@/routes'

  // Someone named on the review page, linked to their admin page in a new tab so the review stays open. Their page
  // is admin-only, so for other reviewers it's just the name.
  let {
    person,
    avatar = false,
    class: className = '',
  }: {
    person: { id: string; name: string; avatar: string }
    avatar?: boolean
    class?: string
  } = $props()

  const linked = $derived(shared().auth.user?.is_admin ?? false)
</script>

{#snippet face()}
  {#if avatar}
    <img
      src={person.avatar}
      alt=""
      width="16"
      height="16"
      class="size-4 shrink-0 rounded-full bg-muted object-cover"
    />
  {/if}
  <span class={['truncate', linked && 'group-hover:underline']}>{person.name}</span>
{/snippet}

{#if linked}
  <a
    href={adminUser(person.id).url}
    target="_blank"
    rel="noopener"
    class="group inline-flex min-w-0 items-center gap-1.5 {className}">{@render face()}</a
  >
{:else}
  <span class="inline-flex min-w-0 items-center gap-1.5 {className}">{@render face()}</span>
{/if}
