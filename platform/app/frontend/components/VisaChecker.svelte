<script lang="ts">
  import { fly } from 'svelte/transition'
  import { CHECKED, countries, search, type Country, type VisaStatus } from '@/lib/chinaVisa'
  import * as sfx from '@/lib/sfx'

  // The Visas doc's picker: type or tap a passport and see whether it needs a visa for Shenzhen. The pick is kept in
  // this browser so the answer is there next time. The list opens in the page's flow, not over it, because the docs
  // panel clips anything that hangs out of it.
  const KEY = 'fallen:passport'
  const SUGGESTED = ['US', 'CA', 'GB', 'IN']

  const all = countries()
  const byCode = new Map(all.map((c) => [c.code, c]))

  let query = $state('')
  let open = $state(false)
  let active = $state(0)
  let picked = $state<Country | undefined>(byCode.get(saved() ?? ''))
  let input = $state<HTMLInputElement>()
  let listbox = $state<HTMLUListElement>()

  const results = $derived(search(all, query))
  const reduced = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

  function saved() {
    try {
      return localStorage.getItem(KEY)
    } catch {
      return null
    }
  }

  function pick(country: Country) {
    picked = country
    query = ''
    open = false
    sfx.select()
    try {
      localStorage.setItem(KEY, country.code)
    } catch {
      // Private windows can refuse storage; the answer still shows.
    }
  }

  function change() {
    picked = undefined
    queueMicrotask(() => input?.focus())
  }

  function onkeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      if (open) event.preventDefault()
      open = false
      return
    }
    if (event.key === 'Enter' && open && results[active]) {
      event.preventDefault()
      pick(results[active])
      return
    }
    const step = { ArrowDown: 1, ArrowUp: -1 }[event.key]
    if (!step) return
    event.preventDefault()
    if (!open) return void (open = true)
    if (!results.length) return
    active = (active + step + results.length) % results.length
    sfx.move()
    listbox?.querySelector(`#passport-${results[active].code}`)?.scrollIntoView({ block: 'nearest' })
  }

  const tone: Record<VisaStatus, string> = {
    free: 'bg-mint',
    citizen: 'bg-mint',
    permit: 'bg-periwinkle',
    transit: 'bg-saffron',
    visa: 'bg-hc-orange',
  }

  const verdict: Record<VisaStatus, string> = {
    free: 'No visa needed',
    citizen: 'No visa needed',
    permit: 'No visa needed',
    transit: 'You probably need a visa',
    visa: 'You need a visa',
  }
</script>

<div
  class="rounded-[4px] bg-white/10 px-5 py-5 [&_a]:text-cream [&_a]:underline [&_a]:decoration-cream/40 [&_a]:underline-offset-3 [&_a:hover]:decoration-cream [&_strong]:font-semibold [&_strong]:text-cream"
>
  <p class="sr-only" aria-live="polite">
    {picked ? `${picked.name}: ${verdict[picked.status]}` : ''}
  </p>
  {#if picked}
    <div class="flex flex-wrap items-center justify-between gap-3">
      <p class="flex items-center gap-3 font-montserrat text-lg font-semibold text-white">
        <span class="text-2xl leading-none" aria-hidden="true">{picked.flag}</span>
        <span><span class="sr-only">Passport: </span>{picked.name}</span>
      </p>
      <button
        type="button"
        onclick={change}
        class="cursor-pointer text-sm text-cream underline decoration-cream/40 underline-offset-3 hover:decoration-cream"
      >
        Change
      </button>
    </div>

    {#key picked.code}
      <div in:fly={{ y: 8, duration: reduced ? 0 : 260 }} class="mt-4 space-y-3" data-verdict>
        <p
          class="flex items-center gap-2.5 font-montserrat text-2xl font-semibold tracking-[-0.02em] text-white"
        >
          <span class={['size-3 shrink-0 rounded-full', tone[picked.status]]} aria-hidden="true"></span>
          {verdict[picked.status]}
        </p>

        {#if picked.status === 'free'}
          <p>You can stay up to 30 days without a visa.</p>
        {:else if picked.status === 'transit'}
          <p>You'll need a tourist (L) visa, unless your flights qualify for visa-free transit.</p>
          <p>
            Visa-free transit lets you stay up to 10 days if you fly in from one country and leave for a
            different one, for example, Hong Kong and Macao. Flying into Shenzhen and out of Hong Kong works,
            but going in and out through Hong Kong doesn't.
          </p>
          <p>If you're not sure your route fits, get the visa.</p>
        {:else if picked.status === 'visa'}
          <p>
            Apply for a tourist (L) visa at the <a
              href="https://www.visaforchina.cn"
              target="_blank"
              rel="noreferrer">Chinese visa center</a
            > or embassy in your country. Do it soon.
          </p>
          <p>Your passport needs to be valid for at least 6 months after you arrive.</p>
        {:else if picked.status === 'permit'}
          <p>
            Use your {picked.code === 'TW'
              ? 'Mainland Travel Permit for Taiwan Residents'
              : 'Home Return Permit'}.
          </p>
          <p>Travelling on another passport? Pick that country instead.</p>
        {/if}
      </div>
    {/key}
  {:else}
    <label for="passport" class="block font-montserrat text-lg font-semibold text-white"
      >Which passport are you travelling on?</label
    >
    <input
      bind:this={input}
      bind:value={query}
      id="passport"
      type="text"
      role="combobox"
      autocomplete="off"
      spellcheck="false"
      placeholder="Search for a country"
      aria-expanded={open}
      aria-controls="passports"
      aria-autocomplete="list"
      aria-activedescendant={open && results[active] ? `passport-${results[active].code}` : undefined}
      oninput={() => {
        open = true
        active = 0
      }}
      onfocus={() => (open = true)}
      onblur={() => (open = false)}
      {onkeydown}
      class="mt-3 w-full rounded-[4px] border-2 border-cream/30 bg-dark-blue/40 px-4 py-3 text-base text-white outline-none placeholder:text-pale-blue/60 focus:border-cream"
    />

    {#if open}
      <ul
        bind:this={listbox}
        id="passports"
        role="listbox"
        aria-label="Passports"
        class="mt-2 max-h-64 list-none! space-y-0! overflow-y-auto overscroll-contain rounded-[4px] bg-dark-blue/50 p-1 pl-1!"
      >
        {#each results as country, i (country.code)}
          <!-- mousedown, not click, so the pick lands before the input's blur closes the list. -->
          <li
            id="passport-{country.code}"
            role="option"
            aria-selected={i === active}
            onmousedown={(event) => {
              event.preventDefault()
              pick(country)
            }}
            onmousemove={() => (active = i)}
            class={[
              'mt-0! flex cursor-pointer items-center gap-3 rounded-[3px] px-3 py-2',
              i === active && 'bg-white/15 text-white',
            ]}
          >
            <span class="text-xl leading-none" aria-hidden="true">{country.flag}</span>
            {country.name}
          </li>
        {:else}
          <li class="mt-0! px-3 py-2 text-pale-blue/70">No country called "{query}"</li>
        {/each}
      </ul>
    {:else}
      <div class="mt-3 flex flex-wrap gap-2">
        {#each SUGGESTED as code (code)}
          {@const country = byCode.get(code)!}
          <button
            type="button"
            onclick={() => pick(country)}
            class="flex cursor-pointer items-center gap-2 rounded-full bg-white/10 px-3 py-1.5 text-sm text-cream transition hover:bg-white/20"
          >
            <span aria-hidden="true">{country.flag}</span>
            {country.name}
          </button>
        {/each}
      </div>
    {/if}
  {/if}

  <p class="mt-5 text-sm text-pale-blue/70">
    Last checked {CHECKED}
  </p>
</div>
