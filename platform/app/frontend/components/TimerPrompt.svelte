<script lang="ts" module>
  // Wide enough for the pause prompt's two buttons side by side.
  export const PROMPT_WIDTH = 320
</script>

<script lang="ts">
  import { enter, exit } from '@/components/dialog/motion'
  import { inviteToHuddle, pauseHuddle, startTimer, timer } from '@/lib/timer.svelte'

  // A bubble above the desktop pet, pointing down at it, for the pet's timer (PetTimer):
  // - join: Start was pressed. Join the huddle, where time counts by itself, or "I'd prefer not" and count it on
  //   the site's timer.
  // - pause: Pause was pressed in the huddle. Stay and stop counting, or leave.
  // - leave: the site cannot take anyone out of a Slack huddle, so it says how; counting stops once Slack says
  //   they left.
  // Lives inside the pet's moving element (DesktopPet), which holds still while it is open. `shift` moves it
  // sideways to stay inside the window, the tail still over the pet.
  let { shift = 0 }: { shift?: number } = $props()

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
      <!-- the tail, pointing down at the pet -->
      <span
        class="absolute -bottom-[9px] size-4 rotate-45 border-r-2 border-b-2 border-gold bg-dark-blue"
        style:left="{PROMPT_WIDTH / 2 - shift - 8}px"
      ></span>
    </div>
  </div>
{/if}
