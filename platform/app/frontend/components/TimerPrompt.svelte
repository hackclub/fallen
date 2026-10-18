<script lang="ts">
  import { enter, exit } from '@/components/dialog/motion'
  import { inviteToHuddle, pauseHuddle, startTimer, timer } from '@/lib/timer.svelte'

  // Drops in from the top of the window for the pet's timer (PetTimer):
  // - join: Start was pressed. Join the huddle, where time counts by itself, or "I'd prefer not" and count it on
  //   the site's timer.
  // - pause: Pause was pressed in the huddle. Stay and stop counting, or leave.
  // - leave: the site cannot take anyone out of a Slack huddle, so it says how; counting stops once Slack says
  //   they left.
  // On <body>, so the pet's moving element does not carry it along.
  const close = () => (timer.prompt = null)

  function onkeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') close()
  }

  const primary = 'rounded-full bg-gold px-4 py-1.5 text-sm font-semibold text-dark-blue hover:brightness-110'
  const secondary = 'text-xs text-pale-blue/80 underline-offset-2 hover:text-cream hover:underline'
  const titles = { join: 'Join the huddle?', pause: 'Stop counting?', leave: 'Leave from Slack' }
</script>

<svelte:window {onkeydown} />

{#if timer.prompt}
  <div
    role="dialog"
    aria-labelledby="timer-prompt-title"
    class="fixed top-4 left-1/2 z-[90] w-[min(92vw,380px)] -translate-x-1/2"
    {@attach (el) => {
      document.body.append(el)
      return () => el.remove()
    }}
  >
    <div
      class="rounded-2xl border-2 border-gold bg-dark-blue px-5 py-4 font-outfit text-cream shadow-[0_10px_30px_-8px_rgba(0,0,0,0.7)]"
      {@attach enter(
        { opacity: 0, y: -24, scale: 0.96 },
        { opacity: 1, y: 0, scale: 1 },
        { type: 'spring', stiffness: 420, damping: 26 },
      )}
      out:exit={{ target: { opacity: 0, y: -16 }, transition: { duration: 0.14 }, duration: 0.14 }}
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
          <button type="button" class={secondary} onclick={startTimer}>I'd prefer not</button>
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
    </div>
  </div>
{/if}
