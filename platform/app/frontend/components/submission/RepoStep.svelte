<script lang="ts">
  import { checkRepository } from '@/lib/submission'
  import type { RepoSnapshot } from '@/types'

  // Reads the repository on our side (RepoSnapshotJob) so the reviewer sees it as it was sent. Any public git host
  // works: GitHub, GitLab, Codeberg, your own Forgejo...
  let {
    projectId,
    url = $bindable(),
    snapshot = $bindable(),
    checkedUrl = $bindable(),
    onChecked,
  }: {
    projectId: string
    url: string
    snapshot: RepoSnapshot | null
    checkedUrl: string
    onChecked: (snapshot: RepoSnapshot) => void
  } = $props()

  let checking = $state(false)
  let error = $state<string | null>(null)

  // Editing the link after a check means it has to be checked again.
  $effect(() => {
    if (snapshot && url.trim() !== checkedUrl) snapshot = null
  })

  async function check(event?: SubmitEvent) {
    event?.preventDefault()
    if (checking || !url.trim()) return
    checking = true
    error = null
    snapshot = null
    const asked = url.trim()
    try {
      const result = await checkRepository(projectId, asked)
      if (result.status === 'failed') error = result.error ?? 'Couldn’t read that repository'
      else {
        checkedUrl = asked
        snapshot = result
        onChecked(result)
      }
    } catch (e) {
      error = e instanceof Error ? e.message : 'Couldn’t read that repository'
    } finally {
      checking = false
    }
  }

  const short = (sha: string | null) => sha?.slice(0, 7) ?? ''
</script>

<p class="text-center text-sm text-ink-soft">
  Paste the link to your project’s public repository (e.g. GitHub).
</p>

<form class="mt-5 flex flex-col gap-2 sm:flex-row" onsubmit={check} novalidate>
  <label for="repo-url" class="sr-only">Repository link</label>
  <input
    id="repo-url"
    type="url"
    inputmode="url"
    autocomplete="off"
    spellcheck="false"
    placeholder="https://github.com/you/your-project"
    bind:value={url}
    class="paper-input flex-1 text-base"
  />
  <button type="submit" class="game-btn game-btn-white shrink-0" disabled={checking || !url.trim()}>
    {checking ? 'Reading...' : snapshot ? 'Check again' : 'Check it'}
  </button>
</form>

<div class="mt-4 min-h-24" aria-live="polite">
  {#if checking}
    <div
      class="flex items-center gap-3 rounded-xl border-2 border-dashed border-paper-rim px-4 py-4 text-sm text-ink-soft"
    >
      <span class="size-4 shrink-0 animate-spin rounded-full border-2 border-ink/20 border-t-[#1cb0f6]"
      ></span>
      Reading your repository. This can take up to a minute.
    </div>
  {:else if error}
    <div class="rounded-xl border-2 border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>
  {:else if snapshot?.status === 'done'}
    <div class="rounded-xl border-2 border-[#1cb0f6]/40 bg-[#fffdf8] px-4 py-3.5">
      <p class="flex items-center gap-2 text-sm font-semibold text-ink">
        <span class="grid size-5 place-items-center rounded-full bg-[#58cc02] text-white" aria-hidden="true">
          <svg viewBox="0 0 12 12" class="size-3" fill="none" stroke="currentColor" stroke-width="2.2"
            ><path d="M2.5 6.5l2.5 2.5 4.5-6" stroke-linecap="round" stroke-linejoin="round" /></svg
          >
        </span>
        <span class="truncate">{snapshot.url.replace(/^https:\/\//, '')}</span>
      </p>
      <dl class="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-xs text-ink-soft">
        <div>
          <dt class="inline">Branch</dt>
          <dd class="inline font-mono text-ink">{snapshot.branch}</dd>
        </div>
        <div>
          <dt class="inline">Commit</dt>
          <dd class="inline font-mono text-ink">{short(snapshot.commit_sha)}</dd>
        </div>
        <div>
          <dd class="inline text-ink">
            {snapshot.file_count.toLocaleString()}{snapshot.tree_truncated ? '+' : ''}
          </dd>
          <dt class="inline">files</dt>
        </div>
      </dl>
      <ul class="mt-3 flex flex-wrap gap-2 text-xs">
        <li
          class={[
            'rounded-full px-2.5 py-1',
            snapshot.readme_path ? 'bg-[#e5f8d4] text-[#2b6a00]' : 'bg-red-50 text-red-800',
          ]}
        >
          {snapshot.readme_path ? `${snapshot.readme_path} found` : 'No README'}
        </li>
        <li
          class={[
            'rounded-full px-2.5 py-1',
            snapshot.bom_path ? 'bg-[#e5f8d4] text-[#2b6a00]' : 'bg-amber-50 text-amber-800',
          ]}
        >
          {snapshot.bom_path ? `${snapshot.bom_path} found` : 'No bom.csv in the repo'}
        </li>
      </ul>
      <p class="mt-3 text-xs text-ink-soft">
        This is what the reviewer sees. Modified something since? Check your project again before you submit
        it.
      </p>
    </div>
  {/if}
</div>
