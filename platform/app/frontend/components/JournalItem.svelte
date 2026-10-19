<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Markdown from '@/components/Markdown.svelte'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import * as sfx from '@/lib/sfx'
  import { journals } from '@/routes'
  import type { Journal } from '@/types'

  // summer-of-making's devlog card on the glass: who and when on top with a "more" menu for the owner, then the
  // write-up and photos.
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

{#snippet meta(href: string, label: string, title?: string)}
  <a
    {href}
    target="_blank"
    rel="noopener"
    {title}
    class="text-sky-ice/60 transition-colors hover:text-cream hover:underline">{label} ↗</a
  >
{/snippet}

<article id="journal-{journal.id}" class="glass scroll-mt-8 px-5 py-5 md:px-6">
  <header class="mb-3 flex items-start gap-3">
    <img
      src={author.avatar}
      alt=""
      class="size-10 shrink-0 rounded-full bg-sky-night object-cover ring-2 ring-cream/60 sm:size-11"
    />
    <div class="min-w-0 flex-1">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
        <p class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">{author.name}</p>
        {#if journal.duration_text}
          <span class="chip">{journal.duration_text}</span>
          {#if journal.xp != null}
            <span class="chip bg-saffron/20! text-saffron!">+{journal.xp} XP</span>
          {/if}
        {:else}
          <span class="chip bg-saffron/20! text-saffron!">no hours yet</span>
        {/if}
      </div>
      <p class="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 font-outfit text-sm text-sky-ice/60">
        <a
          href="#journal-{journal.id}"
          title={formatDateTime(journal.created_at)}
          class="transition-colors hover:text-cream hover:underline">{timeAgo(journal.created_at)}</a
        >
        {#if journal.slack_url}
          {@render meta(journal.slack_url, journal.source === 'slack' ? 'written in Slack' : 'in Slack')}
        {/if}
        {#each journal.lapse_timelapses as timelapse, i (timelapse.id)}
          {@render meta(
            timelapse.url,
            `timelapse${journal.lapse_timelapses.length > 1 ? ` ${i + 1}` : ''}`,
            timelapse.name ?? undefined,
          )}
        {:else}
          {#if journal.lapse_url}
            {@render meta(journal.lapse_url, 'timelapse')}
          {/if}
        {/each}
      </p>
    </div>

    {#if editable}
      <div bind:this={menu} class="relative shrink-0">
        <button
          type="button"
          aria-label="More"
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          onclick={() => {
            if (!menuOpen) sfx.select()
            menuOpen = !menuOpen
          }}
          class="flex size-9 cursor-pointer items-center justify-center rounded-full text-xl leading-none text-sky-ice/70 transition-colors hover:bg-white/10 hover:text-white focus-visible:outline-2 focus-visible:outline-cream"
        >
          ⋯
        </button>
        {#if menuOpen}
          <div
            role="menu"
            class="absolute top-full right-0 z-20 mt-1 w-36 overflow-hidden rounded-[4px] bg-sky-night/95 py-1 font-montserrat text-sm font-semibold shadow-[0_20px_50px_-15px_rgba(0,0,0,0.8)] ring-1 ring-white/15 backdrop-blur"
          >
            <button
              type="button"
              role="menuitem"
              class="w-full cursor-pointer px-4 py-2.5 text-left text-white hover:bg-white/10"
              onclick={() => ((menuOpen = false), onEdit(journal))}>Edit</button
            >
            <button
              type="button"
              role="menuitem"
              class="w-full cursor-pointer px-4 py-2.5 text-left text-red-300 hover:bg-white/10"
              onclick={remove}>Delete</button
            >
          </div>
        {/if}
      </div>
    {/if}
  </header>

  <Markdown source={journal.body} glass class="max-w-[38em] break-words" />

  {#if journal.images.length > 0 && !journal.body.includes('](/rails/active_storage')}
    <div class="mt-3 grid gap-2 {journal.images.length > 1 ? 'grid-cols-2' : ''}">
      {#each journal.images as image (image.id)}
        <a href={image.url} target="_blank" rel="noopener">
          <img
            src={image.url}
            alt={image.filename}
            loading="lazy"
            class="max-h-96 w-full rounded-[4px] bg-black/20 object-contain transition-opacity hover:opacity-90"
          />
        </a>
      {/each}
    </div>
  {/if}
</article>
