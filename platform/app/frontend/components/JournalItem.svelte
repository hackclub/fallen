<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Markdown from '@/components/Markdown.svelte'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import { journals } from '@/routes'
  import type { Journal } from '@/types'

  // summer-of-making's devlog card: who and when on top with a "more" menu for the owner, then the write-up and photos.
  let {
    journal,
    author,
    editable,
    onEdit,
  }: {
    journal: Journal
    author: { name: string; avatar: string }
    editable: boolean
    onEdit: (journal: Journal) => void
  } = $props()

  let menuOpen = $state(false)
  let menu: HTMLElement | undefined = $state()

  function remove() {
    menuOpen = false
    if (!confirm('Delete this journal? It is removed from the Slack thread too.')) return
    router.delete(journals.destroy(journal.id).url, { preserveScroll: true })
  }
</script>

<svelte:window
  onclick={(e) => menuOpen && !menu?.contains(e.target as Node) && (menuOpen = false)}
  onkeydown={(e) => e.key === 'Escape' && (menuOpen = false)}
/>

<article id="journal-{journal.id}" class="paper scroll-mt-8 p-4 md:p-6">
  <header class="mb-2 flex items-center sm:mb-3">
    <img
      src={author.avatar}
      alt=""
      class="mr-2 h-8 w-8 rounded-full bg-sky-night object-cover sm:mr-3 sm:h-10 sm:w-10"
    />
    <div class="font-outfit">
      <p class="text-base text-ink sm:text-lg">{author.name}</p>
      <p class="text-sm text-ink-soft">
        {#if journal.duration_text}
          <span>{journal.duration_text}</span>
          {#if journal.xp != null}
            <span> • </span>
            <span class="text-ink">+{journal.xp} XP</span>
          {/if}
        {:else}
          <span class="text-amber-700">no hours yet</span>
        {/if}
        <span> • </span>
        <a
          href="#journal-{journal.id}"
          title={formatDateTime(journal.created_at)}
          class="transition-colors duration-200 hover:text-ink hover:underline"
          >{timeAgo(journal.created_at)}</a
        >
        {#if journal.slack_url}
          <span> • </span>
          <a href={journal.slack_url} target="_blank" rel="noopener" class="hover:text-ink hover:underline">
            {journal.source === 'slack' ? 'written in Slack' : 'in Slack'} ↗
          </a>
        {/if}
        {#if journal.lapse_timelapse || journal.lapse_url}
          <span> • </span>
          <a
            href={journal.lapse_timelapse?.url ?? journal.lapse_url}
            target="_blank"
            rel="noopener"
            class="hover:text-ink hover:underline">timelapse ↗</a
          >
        {/if}
      </p>
    </div>

    {#if editable}
      <div bind:this={menu} class="relative ml-auto self-start">
        <button
          type="button"
          aria-label="More"
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          onclick={() => (menuOpen = !menuOpen)}
          class="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full text-xl leading-none text-ink-soft transition-colors duration-200 hover:bg-ink/5 hover:text-ink"
        >
          ⋯
        </button>
        {#if menuOpen}
          <div
            role="menu"
            class="paper absolute top-full right-0 z-20 mt-1 w-32 py-1 font-outfit text-sm shadow-lg"
          >
            <button
              type="button"
              role="menuitem"
              class="w-full cursor-pointer px-4 py-2 text-left text-ink hover:bg-ink/5"
              onclick={() => ((menuOpen = false), onEdit(journal))}>Edit</button
            >
            <button
              type="button"
              role="menuitem"
              class="w-full cursor-pointer px-4 py-2 text-left text-red-700 hover:bg-ink/5"
              onclick={remove}>Delete</button
            >
          </div>
        {/if}
      </div>
    {/if}
  </header>

  <Markdown source={journal.body} class="max-w-[38em] break-words" />

  {#if journal.images.length > 0 && !journal.body.includes('](/rails/active_storage')}
    <div class="mt-2 grid gap-2 sm:mt-3 {journal.images.length > 1 ? 'grid-cols-2' : ''}">
      {#each journal.images as image (image.id)}
        <a href={image.url} target="_blank" rel="noopener">
          <img
            src={image.url}
            alt={image.filename}
            loading="lazy"
            class="max-h-96 w-full rounded-lg object-contain transition-opacity hover:opacity-90"
          />
        </a>
      {/each}
    </div>
  {/if}
</article>
