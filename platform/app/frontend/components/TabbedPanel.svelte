<script lang="ts" generics="Id extends string">
  import { onMount, type Snippet } from 'svelte'
  import { flashOnClick, nudge, nudgeSpring, reveal } from '@/lib/rail'
  import * as sfx from '@/lib/sfx'
  import { stagger } from '@/lib/stagger'

  // Settings and Docs: a rail of tabs beside a glass panel, moved through like a game menu. The tabs feel like the
  // nav rail, arrow keys step through them with a blip, the open tab is kept in the URL (the hash, /settings#sound, or
  // the path from `href`, /docs/journaling) without a visit, and the panel eases to the height of what is open while its children fade in one after another.
  // Below lg the rail sits above the panel: tabs without icons stay a column; with icons they become a row that keeps
  // only the open tab's word, scrolling sideways when it is still wider than the phone. From lg the rail is as wide as
  // its longest label, never under 200px, and stays in view as the page scrolls.
  let {
    items,
    label,
    current = $bindable(),
    panelClass = '',
    href,
    panel,
    after,
  }: {
    items: { id: Id; label: string; icon?: Snippet }[]
    label: string
    current: Id
    panelClass?: string
    href?: (id: Id) => string
    panel: Snippet<[Id]>
    after?: Snippet<[Id]>
  } = $props()

  const springs: Record<string, ReturnType<typeof nudgeSpring>> = {}
  const spring = (id: Id) => (springs[id] ??= nudgeSpring())
  const ids = $derived(items.map((item) => item.id))
  const row = $derived(items.every((item) => item.icon))
  const tabs: Record<string, HTMLButtonElement> = $state({})
  let height = $state(0)

  const url = (id: Id) => href?.(id) ?? `#${id}`

  // With `href`, an old hash link (/docs#journaling) still opens its tab.
  onMount(() => {
    const id = ids.find((id) => location.pathname === url(id)) ?? (location.hash.slice(1) as Id)
    if (ids.includes(id)) current = id
  })

  let list: HTMLUListElement
  $effect(() => reveal(list, tabs[current]))

  function open(id: Id) {
    if (id === current) return
    current = id
    history.replaceState(history.state, '', url(id))
  }

  function onkeydown(event: KeyboardEvent) {
    const i = ids.indexOf(current)
    const to: Record<string, number> = {
      ArrowDown: i + 1,
      ArrowRight: i + 1,
      ArrowUp: i - 1,
      ArrowLeft: i - 1,
      Home: 0,
      End: ids.length - 1,
    }
    if (!(event.key in to)) return
    event.preventDefault()
    const next = ids[(to[event.key] + ids.length) % ids.length]
    if (next === current) return
    sfx.move()
    open(next)
    tabs[next]?.focus()
  }
</script>

<div
  class="grid grid-cols-[minmax(0,1fr)] gap-6 lg:grid-cols-[minmax(200px,max-content)_minmax(0,1fr)] lg:items-start"
>
  <!-- svelte-ignore a11y_interactive_supports_focus -->
  <ul
    bind:this={list}
    role="tablist"
    aria-label={label}
    aria-orientation="vertical"
    {onkeydown}
    {@attach flashOnClick}
    class={[
      'rail flex overflow-hidden rounded-[4px] bg-white/10 lg:sticky lg:top-8 lg:w-auto lg:flex-col',
      row ? 'rail-row w-fit max-w-full [scrollbar-width:none] max-lg:overflow-x-auto' : 'flex-col',
    ]}
  >
    {#each items as item (item.id)}
      <li {@attach nudge(spring(item.id))} class="shrink-0 lg:w-full" role="presentation">
        <button
          bind:this={tabs[item.id]}
          type="button"
          role="tab"
          id="tab-{item.id}"
          aria-selected={current === item.id}
          aria-controls="panel-{item.id}"
          tabindex={current === item.id ? 0 : -1}
          onclick={() => {
            if (item.id !== current) sfx.select()
            open(item.id)
          }}
          class="rail-item w-full cursor-pointer text-left"
        >
          <span
            class="relative z-10 flex items-center gap-3 drop-shadow-[0_1.5px_4px_rgba(0,0,0,0.35)]"
            style:transform="translateX({spring(item.id).current}px)"
          >
            {#if item.icon}<span class="shrink-0">{@render item.icon()}</span>{/if}
            <span class={['whitespace-nowrap lg:pr-8', row && current !== item.id && 'max-lg:sr-only']}
              >{item.label}</span
            >
          </span>
        </button>
      </li>
    {/each}
  </ul>

  <div class="min-w-0">
    <div
      class="overflow-hidden rounded-[4px] bg-white/10 transition-[height] duration-[420ms] ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none"
      style:height={height ? `${height}px` : undefined}
    >
      {#key current}
        <div
          bind:offsetHeight={height}
          {@attach stagger}
          role="tabpanel"
          id="panel-{current}"
          aria-labelledby="tab-{current}"
          class="stagger-in {panelClass}"
        >
          {@render panel(current)}
        </div>
      {/key}
    </div>
    {@render after?.(current)}
  </div>
</div>
