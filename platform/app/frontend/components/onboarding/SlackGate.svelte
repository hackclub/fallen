<script lang="ts">
  import { page, router } from '@inertiajs/svelte'
  import ModalButton from '@/components/ModalButton.svelte'
  import Modal from '@/components/Modal.svelte'
  import { PET_EGGS } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'
  import { slackGateDue } from '@/lib/slackGate.svelte'
  import { connectSlack, devSkipSlack, signIn, signOut, skipSlack } from '@/routes'

  const setup = $derived(shared().setup)
  const due = $derived(slackGateDue())
  const egg = $derived(PET_EGGS[shared().auth.user?.pet ?? ''])
</script>

{#if due}
  <!-- Not portalled: it stays in the layout's stacking context, under the nav rail. Beside the rail on a wide
       screen, a sheet at the bottom on a phone. -->
  <Modal
    titleId="slack-gate-title"
    title={setup?.step === 'verify' ? 'Sign in to keep going' : 'Connect Slack to start'}
    class="max-w-md"
    backdropClass="max-md:items-end md:pl-[300px]"
  >
    <div class="flex flex-col items-center px-6 pt-3 pb-6 text-center font-outfit md:px-9 md:pb-7">
      {#if setup?.step === 'verify'}
        {#if egg}
          <img src={egg} alt="" class="gate-icon h-24 w-auto drop-shadow-[0_5px_0_rgba(0,0,0,0.12)]" />
        {/if}
        <p class="mt-4 text-[15px] text-balance text-ink">
          Make a Hack Club account to keep your pet and your project, and to start tracking time.
        </p>
        <ModalButton
          kind="confirm"
          class="mt-6 w-full max-w-72"
          href={signIn({ query: { login_hint: setup.email } }).url}
        >
          Continue with Hack Club
        </ModalButton>
      {:else}
        <div
          class="gate-icon grid size-20 place-items-center rounded-[24px] bg-white shadow-[0_5px_0_var(--color-paper-rim)]"
        >
          <svg viewBox="0 0 122.8 122.8" class="size-11" aria-hidden="true">
            <path
              d="M25.8 77.6a12.9 12.9 0 1 1-12.9-12.9h12.9zm6.5 0a12.9 12.9 0 0 1 25.8 0v32.3a12.9 12.9 0 0 1-25.8 0z"
              fill="#e01e5a"
            />
            <path
              d="M45.2 25.8a12.9 12.9 0 1 1 12.9-12.9v12.9zm0 6.5a12.9 12.9 0 0 1 0 25.8H12.9a12.9 12.9 0 0 1 0-25.8z"
              fill="#36c5f0"
            />
            <path
              d="M97 45.2a12.9 12.9 0 1 1 12.9 12.9H97zm-6.5 0a12.9 12.9 0 0 1-25.8 0V12.9a12.9 12.9 0 0 1 25.8 0z"
              fill="#2eb67d"
            />
            <path
              d="M77.6 97a12.9 12.9 0 1 1-12.9 12.9V97zm0-6.5a12.9 12.9 0 0 1 0-25.8h32.3a12.9 12.9 0 0 1 0 25.8z"
              fill="#ecb22e"
            />
          </svg>
        </div>
        <p class="mt-4 text-[15px] text-balance text-ink">
          Your journals post to your project's thread in Slack, as you.
        </p>
        <ModalButton
          kind="confirm"
          class="mt-6 w-full max-w-72"
          href={connectSlack({ query: { return_to: page.url } }).url}
        >
          Connect Slack
        </ModalButton>
        <ModalButton
          kind="cancel"
          class="mt-2 w-full max-w-72"
          onclick={() => router.post(skipSlack().url, {}, { preserveScroll: true })}
        >
          Skip, post through the bot
        </ModalButton>
        <p class="mt-3 text-xs text-ink-soft">
          Skipping means Fallen's bot posts them under your name and picture. They still go to Hack Club
          Slack, so its <a
            href="https://hackclub.com/conduct/"
            target="_blank"
            rel="noopener"
            class="underline">code of conduct</a
          >
          applies. You can connect later in Settings.
        </p>
      {/if}
      <div class="mt-4 flex justify-center gap-4 text-xs text-ink-soft">
        <button type="button" class="underline hover:text-ink" onclick={() => router.visit(signOut())}
          >Sign out</button
        >
        {#if import.meta.env.DEV && setup?.step === 'slack'}
          <button
            type="button"
            class="underline hover:text-ink"
            onclick={() => router.post(devSkipSlack().url, {}, { preserveScroll: true })}>Skip (dev)</button
          >
        {/if}
      </div>
    </div>
  </Modal>
{/if}

<style>
  /* Bounces in after the card lands, then bobs. */
  .gate-icon {
    animation:
      gate-in 0.5s cubic-bezier(0.34, 1.7, 0.64, 1) 0.18s both,
      gate-bob 2.4s ease-in-out 0.7s infinite;
  }
  @keyframes gate-in {
    from {
      opacity: 0;
      transform: scale(0.3) rotate(-12deg);
    }
  }
  @keyframes gate-bob {
    50% {
      transform: translateY(-4px) rotate(-3deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .gate-icon {
      animation: none;
    }
  }
</style>
