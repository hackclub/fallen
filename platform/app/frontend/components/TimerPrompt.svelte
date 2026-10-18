<script lang="ts" module>
  // Wide enough for the pause prompt's two buttons side by side.
  export const PROMPT_WIDTH = 320
</script>

<script lang="ts">
  import { untrack } from 'svelte'
  import { enter, exit } from '@/components/dialog/motion'
  import { inviteToHuddle, pauseHuddle, startTimer, timer, wrapUpTimer } from '@/lib/timer.svelte'

  // A bubble above the desktop pet, pointing down at it, for the pet's timer (PetTimer):
  // - join: Start was pressed. Join the huddle, where time counts by itself, or "I'd prefer not" and count it on
  //   the site's timer.
  // - start: the site's timer. What they are working on, and a tick that they know it stops at timer.maxHours.
  // - wrapUp: the site's timer stopped (or ran out). What they got done, and on a slider how many of the counted
  //   hours were really work; fewer comes off their time. No skip: closing it brings it back on the next Start.
  // - goal: Start was pressed while chilling in the huddle. It counts now, and Slack asks what they are working on.
  // - pause: Pause was pressed in the huddle. Stay and stop counting, or leave.
  // - leave: the site cannot take anyone out of a Slack huddle, so it says how; counting stops once Slack says
  //   they left.
  // Lives inside the pet's moving element (DesktopPet), which holds still while it is open. `shift` moves it
  // sideways to stay inside the window, the tail still over the pet.
  let { shift = 0 }: { shift?: number } = $props()

  const close = () => (timer.prompt = null)

  let goal = $state('')
  let aware = $state(false)
  let done = $state('')
  // The honest-hours slider, in minutes so it moves smoothly; it starts on everything the timer counted.
  let minutes = $state(0)
  const counted = $derived(Math.round(Number(timer.wrapUp?.hours ?? 0) * 60))
  const asHours = (total: number) => String(Math.round((total / 60) * 100) / 100)
  let error = $state('')
  let busy = $state(false)
  // Each bubble opens empty, the slider on everything counted. Only on opening: polls refresh timer.wrapUp.
  $effect(() => {
    const prompt = timer.prompt
    untrack(() => {
      error = ''
      if (prompt === 'start') [goal, aware] = ['', false]
      if (prompt === 'wrapUp') [done, minutes] = ['', counted]
    })
  })

  async function submit(action: () => Promise<void>) {
    busy = true
    error = ''
    try {
      await action()
    } catch (failure) {
      error = failure instanceof Error ? failure.message : 'Something went wrong, try again'
    } finally {
      busy = false
    }
  }

  function onkeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') close()
  }

  const primary = 'rounded-full bg-gold px-4 py-1.5 text-sm font-semibold text-dark-blue hover:brightness-110'
  const secondary = 'text-xs text-pale-blue/80 underline-offset-2 hover:text-cream hover:underline'
  const field =
    'mt-1 block rounded-lg border-2 border-gold/40 bg-white/5 px-3 py-1.5 text-sm text-cream placeholder:text-pale-blue/50 focus:border-gold focus:ring-0 focus:outline-none'
  const titles = {
    join: 'Join the huddle?',
    start: 'Start the timer',
    wrapUp: 'What did you get done?',
    goal: 'What are you working on?',
    pause: 'Stop counting?',
    leave: 'Leave from Slack',
  }
</script>

<svelte:window {onkeydown} />

{#if timer.prompt}
  <!-- Its own presses never pick the pet up. -->
  <div
    role="dialog"
    tabindex="-1"
    aria-labelledby="timer-prompt-title"
    class="absolute bottom-full left-1/2 mb-14 cursor-default select-text"
    style:width="{PROMPT_WIDTH}px"
    style:margin-left="{-PROMPT_WIDTH / 2 + shift}px"
    onpointerdown={(event) => event.stopPropagation()}
  >
    <div
      class="relative rounded-2xl border-2 border-gold bg-dark-blue px-5 py-4 text-left font-outfit text-cream shadow-[0_10px_30px_-8px_rgba(0,0,0,0.7)]"
      style:transform-origin="{PROMPT_WIDTH / 2 - shift}px 100%"
      {@attach enter(
        { opacity: 0, scale: 0.6, y: 12 },
        { opacity: 1, scale: 1, y: 0 },
        { type: 'spring', stiffness: 500, damping: 24 },
      )}
      out:exit={{ target: { opacity: 0, scale: 0.85, y: 8 }, transition: { duration: 0.12 }, duration: 0.12 }}
    >
      <div class="flex items-start justify-between gap-3">
        <h2 id="timer-prompt-title" class="font-lora text-lg font-bold">{titles[timer.prompt]}</h2>
        <button
          type="button"
          class="-mt-1 -mr-2 rounded-full px-2 text-xl leading-none text-pale-blue/80 hover:text-cream"
          aria-label="Close"
          onclick={close}>×</button
        >
      </div>

      {#if timer.prompt === 'join'}
        <p class="mt-1 text-sm leading-snug text-pale-blue">
          Work alongside everyone in the Fallen huddle on Slack. Your time there counts by itself.
        </p>
        <div class="mt-4 flex items-center justify-between gap-3">
          <button type="button" class={secondary} onclick={() => (timer.prompt = 'start')}
            >I'd prefer not</button
          >
          {#if timer.huddleUrl}
            <a href={timer.huddleUrl} target="_blank" rel="noopener" class={primary} onclick={inviteToHuddle}
              >Invite me</a
            >
          {:else}
            <!-- No huddle running and no way to ring them (local development, mostly) -->
            <button
              type="button"
              class={[primary, 'disabled:opacity-50']}
              disabled={!timer.canRing}
              onclick={inviteToHuddle}>Invite me</button
            >
          {/if}
        </div>
      {:else if timer.prompt === 'start'}
        <form onsubmit={(event) => (event.preventDefault(), submit(() => startTimer(goal)))}>
          <label class="mt-2 block text-sm text-pale-blue">
            What are you working on?
            <!-- svelte-ignore a11y_autofocus -->
            <input class={[field, 'w-full']} bind:value={goal} maxlength="500" required autofocus />
          </label>
          <label class="mt-3 flex items-start gap-2 text-sm leading-snug text-pale-blue">
            <input type="checkbox" bind:checked={aware} required class="mt-0.5 rounded text-gold" />
            I know the timer stops by itself after {timer.maxHours} hours
          </label>
          {#if error}<p class="mt-2 text-xs text-gold">{error}</p>{/if}
          <div class="mt-4 flex justify-end">
            <button
              type="submit"
              class={[primary, 'disabled:opacity-50']}
              disabled={busy || !aware || !goal.trim()}>Start</button
            >
          </div>
        </form>
      {:else if timer.prompt === 'wrapUp' && timer.wrapUp}
        <form
          onsubmit={(event) => (
            event.preventDefault(),
            submit(() => wrapUpTimer({ done, hours: asHours(minutes) }))
          )}
        >
          {#if timer.wrapUp.goal}
            <p class="mt-1 text-sm leading-snug text-pale-blue">You were working on {timer.wrapUp.goal}.</p>
          {/if}
          <!-- svelte-ignore a11y_autofocus -->
          <textarea
            class={[field, 'mt-2 w-full resize-none']}
            placeholder="What you got done"
            rows="3"
            bind:value={done}
            maxlength="1000"
            required
            autofocus></textarea>
          <label class="mt-3 block text-sm leading-snug text-pale-blue">
            The timer counted {timer.wrapUp.hours} hours. Honestly, how many of those were you working?
            <span class="mt-2 flex items-center gap-3">
              <input
                class="w-full accent-gold"
                type="range"
                min="0"
                max={counted}
                step="1"
                bind:value={minutes}
              />
              <span class="w-20 shrink-0 text-right font-semibold text-cream tabular-nums"
                >{asHours(minutes)} hours</span
              >
            </span>
          </label>
          {#if error}<p class="mt-2 text-xs text-gold">{error}</p>{/if}
          <div class="mt-4 flex justify-end">
            <button type="submit" class={[primary, 'disabled:opacity-50']} disabled={busy || !done.trim()}
              >Save</button
            >
          </div>
        </form>
      {:else if timer.prompt === 'goal'}
        <p class="mt-1 text-sm leading-snug text-pale-blue">
          Your time in the huddle is counting now. We asked in your Slack DMs what you're working on, so
          answer there.
        </p>
        <div class="mt-4 flex items-center justify-end">
          <button type="button" class={primary} onclick={close}>Got it</button>
        </div>
      {:else if timer.prompt === 'pause'}
        <p class="mt-1 text-sm leading-snug text-pale-blue">
          You can hang out in the huddle without the time counting, or leave it.
        </p>
        <div class="mt-4 flex flex-wrap items-center justify-end gap-2">
          <button
            type="button"
            class="rounded-full border-2 border-gold/60 px-4 py-1 text-sm font-semibold hover:bg-white/10"
            onclick={() => (timer.prompt = 'leave')}>Leave the huddle</button
          >
          <button type="button" class={primary} onclick={pauseHuddle}>Stay, stop counting</button>
        </div>
      {:else}
        <p class="mt-1 text-sm leading-snug text-pale-blue">
          Press <strong class="text-cream">Leave</strong> in the huddle in Slack. Your time stops the moment you're
          out.
        </p>
        <div class="mt-4 flex items-center justify-end gap-2">
          {#if timer.huddleUrl}
            <a
              href={timer.huddleUrl}
              target="_blank"
              rel="noopener"
              class="rounded-full border-2 border-gold/60 px-4 py-1 text-sm font-semibold hover:bg-white/10"
              >Open the huddle</a
            >
          {/if}
          <button type="button" class={primary} onclick={close}>Got it</button>
        </div>
      {/if}
      <!-- the tail, pointing down at the pet -->
      <span
        class="absolute -bottom-[9px] size-4 rotate-45 border-r-2 border-b-2 border-gold bg-dark-blue"
        style:left="{PROMPT_WIDTH / 2 - shift - 8}px"
      ></span>
    </div>
  </div>
{/if}
