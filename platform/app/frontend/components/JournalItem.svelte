<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Markdown from '@/components/Markdown.svelte'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import { journals } from '@/routes'
  import type { Journal } from '@/types'

  let { journal, onEdit }: { journal: Journal; onEdit: (journal: Journal) => void } = $props()

  function remove() {
    if (!confirm('Delete this journal? It is removed from the Slack thread too.')) return
    router.delete(journals.destroy(journal.id).url, { preserveScroll: true })
  }
</script>

<li class="paper px-5 py-4 sm:px-6">
  <div class="flex flex-wrap items-center gap-x-3 gap-y-1 font-outfit text-xs text-ink-soft">
    <time datetime={journal.created_at} title={formatDateTime(journal.created_at)} class="text-ink">
      {timeAgo(journal.created_at)}
    </time>
    {#if journal.duration_text}
      <span class="rounded-sm bg-ink px-1.5 py-0.5 text-paper">{journal.duration_text}</span>
    {/if}
    {#if journal.lapse_url}
      <a href={journal.lapse_url} target="_blank" rel="noopener" class="hover:text-ink">timelapse ↗</a>
    {/if}
    {#if journal.slack_url}
      <a href={journal.slack_url} target="_blank" rel="noopener" class="hover:text-ink">
        {journal.source === 'slack' ? 'written in Slack ↗' : 'in Slack ↗'}
      </a>
    {/if}
    <span class="ml-auto flex gap-3">
      <button type="button" class="hover:text-ink" onclick={() => onEdit(journal)}>edit</button>
      <button type="button" class="hover:text-red-700" onclick={remove}>delete</button>
    </span>
  </div>

  <Markdown source={journal.body} class="mt-2" />

  {#if journal.images.length > 0 && !journal.body.includes('](/rails/active_storage')}
    <ul class="mt-3 flex flex-wrap gap-2">
      {#each journal.images as image (image.id)}
        <li>
          <a href={image.url} target="_blank" rel="noopener">
            <img
              src={image.url}
              alt={image.filename}
              class="h-28 rounded-sm border border-paper-edge object-cover"
            />
          </a>
        </li>
      {/each}
    </ul>
  {/if}
</li>
