<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { Person } from '@/types'
  import defaultBanner from '@/assets/hero/default-banner.jpg'

  // What someone sent a join link or an invite sees before saying yes: the project, who is on it, and what joining
  // means for their hours, said plainly before anything else, since that is what teams get wrong. The buttons are
  // the caller's.
  let {
    title,
    description,
    bannerUrl,
    teammates,
    headline,
    full,
    children,
  }: {
    title: string
    description: string | null
    bannerUrl: string | null
    teammates: Person[]
    headline: Snippet
    full: boolean
    children: Snippet
  } = $props()

  const promises = [
    'You journal your own sessions, on the project page or in its Slack thread.',
    "Your hours, XP and pet progress stay yours. Nobody else's journals count for you, and yours never get split.",
    'You can leave whenever you like. Your journals stay yours.',
  ]
</script>

<div class="mx-auto max-w-2xl">
  <section class="glass overflow-hidden">
    <div class="relative h-40 md:h-52">
      <img src={bannerUrl ?? defaultBanner} alt="" class="h-full w-full object-cover" />
      <div class="absolute inset-0 bg-gradient-to-t from-sky-night/80 to-transparent"></div>
      <h1
        class="absolute inset-x-5 bottom-4 font-display text-4xl break-words text-white drop-shadow-[0_2px_10px_rgba(0,0,0,0.5)] md:inset-x-6 md:text-5xl"
      >
        {title}
      </h1>
    </div>

    <div class="px-5 py-5 md:px-6">
      <p class="font-outfit text-lg text-pale-blue">{@render headline()}</p>
      {#if description}
        <p class="mt-3 line-clamp-4 font-outfit whitespace-pre-wrap text-sky-ice/70">{description}</p>
      {/if}

      <ul class="mt-5 flex flex-wrap gap-x-5 gap-y-3">
        {#each teammates as person, i (person.id)}
          <li class="flex items-center gap-2">
            <img
              src={person.avatar}
              alt=""
              class="size-9 rounded-full bg-sky-night object-cover ring-2 ring-cream/60"
            />
            <span class="font-montserrat text-sm font-semibold text-white"
              >{person.name}{#if i === 0}<span class="ml-1.5 font-outfit font-normal text-sky-ice/60"
                  >owner</span
                >{/if}</span
            >
          </li>
        {/each}
      </ul>
    </div>

    <ul class="space-y-2.5 border-t border-white/10 px-5 py-5 md:px-6">
      {#each promises as text (text)}
        <li class="flex items-baseline gap-3 font-outfit text-sm text-sky-ice/80">
          <span class="size-2 shrink-0 translate-y-[-1px] rounded-full bg-cream" aria-hidden="true"
          ></span>{text}
        </li>
      {/each}
    </ul>

    <div class="flex flex-wrap items-center justify-end gap-4 border-t border-white/10 px-5 py-4 md:px-6">
      {#if full}
        <p class="mr-auto font-outfit text-sm text-saffron">
          This team is full. Ask {teammates[0]?.name} if a spot opens up.
        </p>
      {/if}
      {@render children()}
    </div>
  </section>
</div>
