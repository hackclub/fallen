<script lang="ts">
  import NumberInput from '@/components/NumberInput.svelte'
  import { docs } from '@/routes'
  import {
    blankItem,
    importBom,
    itemProblem,
    lineCents,
    MAX_ITEMS,
    money,
    repoBom,
    requestedCents,
    toCents,
    type BomKind,
    type DraftItem,
  } from '@/lib/submission'
  import type { RepoSnapshot } from '@/types'

  // The parts list the funding comes from. It starts filled in from the repo's bom.csv, read on the server after
  // the repository check (BomExtractionJob); an uploaded CSV goes through BomImport. Either way it's then fixed by
  // hand: whatever couldn't be read shows up as a row to finish.
  let {
    items = $bindable(),
    bomCsv = $bindable(),
    snapshot,
  }: { items: DraftItem[]; bomCsv: string; snapshot: RepoSnapshot | null } = $props()

  let input: HTMLInputElement
  let importing = $state(false)
  let warnings = $state<string[]>([])
  let error = $state<string | null>(null)
  let dragging = $state(false)

  const total = $derived(requestedCents(items))
  const problems = $derived(items.filter((item) => itemProblem(item)).length)
  const ordered = $derived([
    ...items.filter((item) => item.kind === 'part'),
    ...items.filter((item) => item.kind !== 'part'),
  ])

  async function load(csv: string, source: string, fromRepo = false) {
    if (items.length > 0 && !confirm(`Replace the ${items.length} rows you have with ${source}?`)) return
    importing = true
    error = null
    try {
      const result = fromRepo && snapshot ? await repoBom(snapshot) : await importBom(csv)
      if (result.items.length === 0) {
        error = result.warnings[0] ?? `Couldn’t find any parts in ${source}`
        return
      }
      items = result.items
      warnings = result.warnings
      bomCsv = csv
    } catch (e) {
      error = e instanceof Error ? e.message : 'Couldn’t read that file'
    } finally {
      importing = false
    }
  }

  // An empty list starts from the repo's bom.csv without anyone having to ask.
  let started = false
  $effect(() => {
    if (started || items.length > 0 || !snapshot?.bom_csv) return
    started = true
    void load(snapshot.bom_csv, snapshot.bom_path ?? 'bom.csv', true)
  })

  async function upload(file: File | undefined) {
    if (!file) return
    if (file.size > 200_000) return (error = 'That file is too big. A bom.csv is usually a few KB.')
    if (/\.(xlsx|xls|ods|numbers)$/i.test(file.name))
      return (error = 'Export it as CSV first (File, then Download or Export, then CSV).')
    await load(await file.text(), file.name)
  }

  function add(kind: BomKind) {
    if (items.length >= MAX_ITEMS) return
    items = [...items, blankItem(kind)]
    if (kind === 'part') {
      queueMicrotask(() =>
        document.querySelector<HTMLInputElement>(`[data-row="${items.at(-1)!.key}"] input`)?.focus(),
      )
    }
  }

  function remove(key: string) {
    items = items.filter((item) => item.key !== key)
  }

  const hasKind = (kind: BomKind) => items.some((item) => item.kind === kind)
  const placeholderTotal = (item: DraftItem) => {
    const unit = toCents(item.unit)
    return unit == null ? '0' : ((unit * Math.max(item.quantity, 1)) / 100).toFixed(2)
  }
</script>

<div
  role="region"
  aria-label="Bill of materials"
  ondragover={(e) => (e.preventDefault(), (dragging = true))}
  ondragleave={(e) => e.currentTarget === e.target && (dragging = false)}
  ondrop={(e) => {
    e.preventDefault()
    dragging = false
    void upload(e.dataTransfer?.files[0])
  }}
  class={[
    'rounded-2xl transition-colors',
    dragging && 'bg-[#e8f7ff] outline-2 outline-[#1cb0f6] outline-dashed',
  ]}
>
  <p class="text-center text-sm text-ink-soft">
    List every part you need to build it, with a link to buy each one. Ask only for what you need: the fewest
    of each part, the cheapest way to make it.
    <a
      href={docs.show({ page: 'project-funding' }).url}
      target="_blank"
      class="font-semibold text-ink underline underline-offset-2">What can I ask for?</a
    >
  </p>

  <div class="mt-4 flex flex-wrap items-center justify-center gap-2">
    {#if snapshot?.bom_csv}
      <button
        type="button"
        class="game-btn game-btn-blue min-h-10 px-4 text-base"
        disabled={importing}
        onclick={() => load(snapshot.bom_csv!, snapshot.bom_path ?? 'bom.csv', true)}
      >
        Use {snapshot.bom_path ?? 'bom.csv'} from your repo
      </button>
    {/if}
    <button
      type="button"
      class="game-btn game-btn-white min-h-10 px-4 text-base"
      disabled={importing}
      onclick={() => input.click()}
    >
      {importing ? 'Reading...' : 'Upload a CSV'}
    </button>
    {#if items.length > 0}
      <button
        type="button"
        class="game-btn game-btn-white min-h-10 px-4 text-base"
        onclick={() => add('part')}>Add a part</button
      >
    {/if}
  </div>

  {#if error}
    <p class="mt-3 rounded-xl bg-red-50 px-3 py-2 text-center text-sm text-red-800">{error}</p>
  {/if}
  {#each warnings as warning (warning)}
    <p class="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-center text-sm text-amber-900">{warning}</p>
  {/each}

  {#if items.length === 0 && importing}
    <div
      class="mt-5 flex items-center justify-center gap-3 rounded-xl border-2 border-dashed border-paper-rim px-4 py-8 text-sm text-ink-soft"
    >
      <span class="size-4 shrink-0 animate-spin rounded-full border-2 border-ink/20 border-t-[#1cb0f6]"
      ></span>
      Reading {snapshot?.bom_path ?? 'your bill of materials'}...
    </div>
  {:else if items.length === 0}
    <button
      type="button"
      onclick={() => add('part')}
      class="mt-5 flex w-full flex-col items-center gap-1 rounded-xl border-2 border-dashed border-ink/20 bg-paper-well px-4 py-8 text-center hover:border-ink/40"
    >
      <span class="text-sm font-semibold text-ink">No parts yet</span>
      <span class="text-xs text-ink-soft">Drop a CSV here, or start typing them in</span>
    </button>
  {:else}
    <!-- Its own scroll area, so the column names stay in view on a long list. -->
    <div class="mt-5 max-h-[45vh] overflow-auto rounded-xl border-2 border-paper-rim bg-[#fffdf8]">
      <table class="w-full text-left text-sm max-md:min-w-[760px] md:table-fixed">
        <thead
          class="sticky top-0 z-10 bg-[#fffdf8] text-xs text-ink-soft shadow-[0_2px_0_var(--color-paper-rim)]"
        >
          <tr>
            <th class="w-[30%] px-3 py-2 font-semibold">Part, and what it’s for</th>
            <th class="w-14 px-1 py-2 font-semibold">Qty</th>
            <th class="w-20 px-1 py-2 font-semibold">Each ($)</th>
            <th class="w-20 px-1 py-2 font-semibold">Total ($)</th>
            <th class="px-1 py-2 font-semibold">Link</th>
            <th
              class="w-12 px-1 py-2 text-center font-semibold"
              title="Parts you already have cost nothing, but list them anyway">Have it</th
            >
            <th class="w-8"><span class="sr-only">Remove</span></th>
          </tr>
        </thead>
        <tbody>
          {#each ordered as item (item.key)}
            {@const problem = itemProblem(item)}
            <tr
              data-row={item.key}
              class={[
                'border-b border-paper-rim last:border-0 align-top',
                problem && 'bg-red-50/60',
                item.owned && 'text-ink-soft',
              ]}
            >
              <td
                class={[
                  'py-1.5 pr-1 pl-2',
                  problem ? 'border-l-4 border-red-400' : 'border-l-4 border-transparent',
                ]}
              >
                {#if item.kind !== 'part'}
                  <span
                    class="mb-0.5 ml-2 inline-block rounded-full bg-ink/8 px-2 py-0.5 text-[11px] font-semibold text-ink-soft uppercase"
                    >{item.kind}</span
                  >
                {/if}
                <input
                  aria-label="Part name"
                  bind:value={item.name}
                  maxlength="200"
                  placeholder="RP2040 microcontroller"
                  class="bom-cell font-semibold"
                />
                {#if item.kind === 'part'}
                  <input
                    aria-label="What it's for"
                    bind:value={item.purpose}
                    maxlength="300"
                    placeholder="What it’s for"
                    class="bom-cell text-xs text-ink-soft"
                  />
                {/if}
                {#if problem}
                  <p class="px-2 pt-0.5 text-xs text-red-700">{problem}</p>
                {/if}
              </td>
              <td class="px-1 py-1.5">
                {#if item.kind === 'part'}
                  <NumberInput
                    label="Quantity"
                    value={item.quantity ? String(item.quantity) : ''}
                    onchange={(value) => (item.quantity = Number(value))}
                    decimals={0}
                    max={10000}
                    placeholder="1"
                    class="bom-cell"
                  />
                {/if}
              </td>
              <td class="px-1 py-1.5">
                {#if item.kind === 'part'}
                  <NumberInput
                    label="Price each"
                    bind:value={item.unit}
                    separators
                    placeholder="0.00"
                    class="bom-cell"
                  />
                {/if}
              </td>
              <td class="px-1 py-1.5">
                <NumberInput
                  label="Line total"
                  bind:value={item.total}
                  separators
                  placeholder={placeholderTotal(item)}
                  class="bom-cell"
                />
              </td>
              <td class="px-1 py-1.5">
                {#if !item.owned}
                  <input
                    aria-label="Link"
                    type="url"
                    bind:value={item.link}
                    placeholder="https://"
                    class="bom-cell text-xs"
                  />
                {/if}
                <input
                  aria-label="Store"
                  bind:value={item.vendor}
                  maxlength="100"
                  placeholder="Store"
                  class="bom-cell text-xs text-ink-soft"
                />
              </td>
              <td class="px-1 py-1.5 text-center">
                {#if item.kind === 'part'}
                  <input
                    type="checkbox"
                    aria-label="I already have this"
                    bind:checked={item.owned}
                    class="mt-2 size-4.5 rounded border-ink/30 text-[#1cb0f6] focus:ring-[#1cb0f6]"
                  />
                {/if}
              </td>
              <td class="py-1.5 pr-2">
                <button
                  type="button"
                  aria-label="Remove {item.name || 'row'}"
                  onclick={() => remove(item.key)}
                  class="mt-1 grid size-7 place-items-center rounded-full text-ink/40 hover:bg-red-50 hover:text-red-700"
                >
                  <svg viewBox="0 0 12 12" class="size-3" fill="none" stroke="currentColor" stroke-width="2"
                    ><path d="M3 3l6 6M9 3l-6 6" stroke-linecap="round" /></svg
                  >
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <div class="mt-3 flex flex-wrap items-end justify-between gap-3">
      <div class="flex flex-wrap gap-x-4 gap-y-1 text-sm">
        <button type="button" class="font-semibold text-ink-soft hover:text-ink" onclick={() => add('part')}
          >+ Part</button
        >
        {#if !hasKind('shipping')}
          <button
            type="button"
            class="font-semibold text-ink-soft hover:text-ink"
            onclick={() => add('shipping')}>+ Shipping</button
          >
        {/if}
        {#if !hasKind('tax')}
          <button type="button" class="font-semibold text-ink-soft hover:text-ink" onclick={() => add('tax')}
            >+ Tax</button
          >
        {/if}
      </div>
      <div class="text-right">
        <p class="text-xs text-ink-soft">
          {items.length}
          {items.length === 1 ? 'row' : 'rows'}{#if problems > 0}, <span class="text-red-700"
              >{problems} to fix</span
            >{/if}
        </p>
        <p class="font-[Jua] text-2xl text-ink">
          {money(total)} <span class="font-outfit text-sm text-ink-soft">asked for</span>
        </p>
      </div>
    </div>
    {#if items.some((item) => item.owned && (lineCents(item) ?? 0) > 0)}
      <p class="mt-1 text-right text-xs text-ink-soft">Parts you have aren’t counted.</p>
    {/if}
  {/if}
</div>

<input
  bind:this={input}
  type="file"
  accept=".csv,text/csv,text/plain"
  class="hidden"
  onchange={(e) => {
    void upload(e.currentTarget.files?.[0])
    e.currentTarget.value = ''
  }}
/>

<style>
  /* Global so the number fields (NumberInput) get it too; their focus is on the input inside, hence focus-within. */
  :global(.bom-cell) {
    display: block;
    width: 100%;
    border: 1px solid transparent;
    border-radius: 0.5rem;
    background: transparent;
    padding: 0.3rem 0.5rem;
    font-size: inherit;
    color: inherit;
  }
  :global(.bom-cell::placeholder) {
    color: color-mix(in oklab, var(--color-ink-soft) 50%, transparent);
  }
  :global(.bom-cell:hover) {
    background: var(--color-paper-well);
  }
  :global(.bom-cell:focus-within) {
    border-color: #1cb0f6;
    background: #fff;
    outline: none;
    box-shadow: none;
  }
</style>
