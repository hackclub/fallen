<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { money } from '@/lib/submission'
  import { formatDate } from '@/lib/format'
  import { submission as submissionRoute } from '@/routes'
  import * as sfx from '@/lib/sfx'
  import type { Submission } from '@/types'

  // Where the project's design review stands, on its page: a way in when there's nothing yet, what's waiting, and
  // what the reviewer said.
  let {
    submission,
    canSubmit,
    canWithdraw,
    onSubmit,
  }: { submission: Submission | null; canSubmit: boolean; canWithdraw: boolean; onSubmit: () => void } =
    $props()

  let withdrawing = $state(false)

  function withdraw() {
    if (!submission || !confirm('Take your submission back? You can submit it again when it’s ready.')) return
    withdrawing = true
    router.delete(submissionRoute(submission.id).url, {
      preserveScroll: true,
      onFinish: () => (withdrawing = false),
    })
  }

  const cut = $derived(
    submission?.bom_items.filter((item) => item.verdict && item.verdict !== 'approved') ?? [],
  )
  const payout = $derived(
    submission?.payout_status === 'sent'
      ? 'Sent! Check your email for the HCB card grant.'
      : 'We’ll send it to you by email, as an HCB card grant.',
  )
</script>

{#if submission?.status === 'pending'}
  <section class="glass px-5 py-5 md:px-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 class="flex items-center gap-2.5 font-montserrat text-lg font-semibold text-white">
          <span class="relative flex size-2.5"
            ><span class="absolute inline-flex size-full animate-ping rounded-full bg-sky-300 opacity-60"
            ></span><span class="relative inline-flex size-2.5 rounded-full bg-sky-300"></span></span
          >
          Design waiting for review
        </h2>
        <p class="mt-1 font-outfit text-sm text-sky-ice/70">
          Sent {formatDate(submission.created_at)}, asking for {money(submission.requested_cents)}. A reviewer
          will read your journals and check your repo. When your project has been reviewed, you’ll receive a
          Slack message!
        </p>
      </div>
      {#if canWithdraw}
        <button type="button" class="pill-glass h-10 text-sm" disabled={withdrawing} onclick={withdraw}>
          {withdrawing ? 'Unsubmitting...' : 'Unsubmit'}
        </button>
      {/if}
    </div>
  </section>
{:else if submission?.status === 'approved'}
  <section class="glass overflow-hidden">
    <div class="px-5 py-5 md:px-6">
      <h2 class="font-montserrat text-lg font-semibold text-white">Design approved!</h2>
      {#if (submission.approved_cents ?? 0) > 0}
        <p class="mt-1 font-outfit text-pale-blue">
          <span class="font-display text-3xl text-white">{money(submission.approved_cents)}</span> to build
          it. {payout}
        </p>
      {:else}
        <p class="mt-1 font-outfit text-sm text-sky-ice/70">Start building!!</p>
      {/if}
      {#if submission.feedback}
        <blockquote
          class="mt-3 border-l-2 border-white/25 pl-3 font-outfit text-sm whitespace-pre-wrap text-sky-ice/80"
        >
          {submission.feedback}
        </blockquote>
      {/if}
    </div>
    {#if cut.length > 0}
      <details class="border-t border-white/10 px-5 py-3 font-outfit text-sm text-sky-ice/70 md:px-6">
        <summary class="cursor-pointer font-semibold text-sky-ice/90"
          >What changed in your parts list ({cut.length})</summary
        >
        <ul class="mt-2 space-y-1.5">
          {#each cut as item (item.id)}
            <li class="flex flex-wrap justify-between gap-x-4">
              <span>
                <span class="text-white">{item.name}</span>: {item.reason}
              </span>
              <span class="tabular-nums">
                <s class="opacity-60">{money(item.owned ? 0 : item.total_cents)}</s>
                {money(item.funded_cents)}
              </span>
            </li>
          {/each}
        </ul>
      </details>
    {/if}
  </section>
{:else if submission?.status === 'returned'}
  <section class="glass px-5 py-5 md:px-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div class="min-w-0 flex-1 basis-72">
        <h2 class="font-montserrat text-lg font-semibold text-white">A few changes before it’s approved</h2>
        {#if submission.feedback}
          <blockquote
            class="mt-2 border-l-2 border-saffron/60 pl-3 font-outfit text-sm whitespace-pre-wrap text-pale-blue"
          >
            {submission.feedback}
          </blockquote>
        {/if}
      </div>
      {#if canSubmit}
        <button type="button" class="pill-cream h-11 text-base" onclick={() => (sfx.select(), onSubmit())}
          >Submit again</button
        >
      {/if}
    </div>
  </section>
{:else if submission?.status === 'rejected'}
  <section class="glass px-5 py-5 md:px-6">
    <h2 class="font-montserrat text-lg font-semibold text-white">Design not approved</h2>
    {#if submission.feedback}
      <blockquote
        class="mt-2 border-l-2 border-white/25 pl-3 font-outfit text-sm whitespace-pre-wrap text-sky-ice/80"
      >
        {submission.feedback}
      </blockquote>
    {/if}
  </section>
{:else if canSubmit}
  <button
    type="button"
    onclick={() => (sfx.select(), onSubmit())}
    class="glass setting-row w-full cursor-pointer overflow-hidden text-left"
  >
    <span
      class="grid size-12 shrink-0 place-items-center rounded-full bg-cream text-slate-ink shadow-[0_0_14px_rgb(252_249_239/0.35)]"
      aria-hidden="true"
    >
      <svg
        viewBox="0 0 24 24"
        class="size-6"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"><path d="M12 19V5M5 12l7-7 7 7" /></svg
      >
    </span>
    <span class="min-w-0 flex-1 basis-56">
      <span class="block font-montserrat text-lg font-semibold tracking-[-0.02em] text-white"
        >Submit your design</span
      >
      <span class="mt-0.5 block font-outfit text-sm text-sky-ice/60"
        >Finished designing it? Submit it for review to get the parts funded!</span
      >
    </span>
    <span class="pill-cream h-11 text-base max-sm:hidden">Submit</span>
  </button>
{/if}
