<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { signIn, trialSession } from '@/routes'

  // Getting started for someone not signed in to Hack Club Auth. An email HCA already knows goes to HCA's sign-in
  // with it filled in; any other starts a trial account (TrialSessionsController), which signs in with HCA after the
  // onboarding. If HCA can't be asked, the server still sends emails with an account here to HCA.
  let { checkEmailUrl, onClose }: { checkEmailUrl: string; onClose: () => void } = $props()

  let email = $state('')
  let busy = $state(false)

  async function knownToHca(value: string) {
    try {
      const response = await fetch(`${checkEmailUrl}?${new URLSearchParams({ email: value })}`)
      const { result } = await response.json()
      return typeof result === 'string' && result !== 'not_found'
    } catch {
      return false
    }
  }

  async function submit(event: SubmitEvent) {
    event.preventDefault()
    if (busy) return
    busy = true
    const value = email.trim().toLowerCase()
    if (await knownToHca(value)) {
      window.location.href = signIn({ query: { login_hint: value } }).url
      return
    }
    router.post(trialSession(), { email: value }, { onFinish: () => (busy = false) })
  }

  const focus = (input: HTMLInputElement) => input.focus()
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<div
  class="fixed inset-0 z-50 flex items-center justify-center overflow-auto bg-dark-blue/70 p-3 backdrop-blur-sm"
  role="dialog"
  aria-modal="true"
  aria-labelledby="get-started-title"
>
  <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}></button>

  <form
    onsubmit={submit}
    class="get-started relative w-full max-w-3xl overflow-hidden rounded-[36px] bg-[#21497f] bg-[url('/assets/hero/background.webp')] bg-cover bg-center px-5 pt-9 pb-7 text-center ring-1 ring-cream/80 ring-offset-6 ring-offset-[#21497f] md:rounded-[48px] md:px-10 md:pt-12 md:pb-10"
  >
    <div class="pointer-events-none absolute inset-0 bg-[#21497f]/75" aria-hidden="true"></div>

    <button
      type="button"
      onclick={onClose}
      aria-label="Close"
      class="absolute top-4 right-5 z-10 flex size-9 cursor-pointer items-center justify-center rounded-full text-cream/70 transition-colors hover:text-cream focus-visible:text-cream md:top-6 md:right-7"
    >
      <svg viewBox="0 0 12 12" class="size-3.5" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M2.5 2.5l7 7M9.5 2.5l-7 7" stroke-linecap="round" />
      </svg>
    </button>

    <div class="relative">
      <h2 id="get-started-title" class="font-lora text-2xl font-semibold text-cream md:text-4xl">
        Get started
      </h2>
      <p class="mx-auto mt-2 max-w-md font-montserrat text-sm text-pale-blue md:text-base">
        Enter your email. If you have a Hack Club account, you'll sign in with it.
      </p>

      <div class="mt-7 flex flex-col items-stretch gap-3 sm:flex-row sm:items-center md:mt-9 md:gap-4">
        <label class="ring-pill flex-1">
          <span class="flex items-center gap-3 rounded-full bg-white/25 px-5 py-3 md:gap-4 md:px-6 md:py-4">
            <span class="size-4 shrink-0 rotate-45 bg-cream md:size-5" aria-hidden="true"></span>
            <span class="sr-only">Email</span>
            <input
              {@attach focus}
              bind:value={email}
              type="email"
              name="email"
              autocomplete="email"
              required
              placeholder="you@example.com"
              class="w-full min-w-0 border-0 bg-transparent p-0 font-montserrat shadow-none focus:ring-0 text-lg font-semibold text-cream placeholder:text-cream/50 focus:outline-none md:text-2xl"
            />
          </span>
        </label>

        <span class="ring-pill">
          <button
            type="submit"
            disabled={busy}
            class="w-full cursor-pointer rounded-full bg-cream px-9 py-3 font-montserrat text-lg font-bold text-indigo transition-[background-color,transform] hover:bg-white active:scale-[0.98] disabled:cursor-wait disabled:opacity-80 md:px-12 md:py-4 md:text-2xl"
          >
            {busy ? 'Starting...' : 'Start!'}
          </button>
        </span>
      </div>
    </div>
  </form>
</div>

<style>
  /* The mockup's double outline: a thin cream line with a gap of sky between it and the pill. */
  .ring-pill {
    display: block;
    border: 1px solid color-mix(in oklab, var(--color-cream) 85%, transparent);
    border-radius: 9999px;
    padding: 7px;
  }
  .ring-pill:focus-within {
    border-color: var(--color-gold);
  }
  .get-started {
    animation: get-started-in 0.22s ease-out both;
  }
  @keyframes get-started-in {
    from {
      opacity: 0;
      transform: scale(0.97);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .get-started {
      animation: none;
    }
  }
</style>
