<script lang="ts">
  import { page, router } from '@inertiajs/svelte'
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import { shared } from '@/lib/shared.svelte'
  import { slackGateDue } from '@/lib/slackGate.svelte'
  import { connectSlack, devSkipSlack, signIn, signOut, skipSlack } from '@/routes'

  const setup = $derived(shared().setup)
  const due = $derived(slackGateDue())
</script>

{#if due}
  <!-- Not portalled: it stays in the layout's stacking context, under the nav rail. Beside the rail on a wide
       screen, a sheet at the bottom on a phone. -->
  <OrnateModal
    titleId="slack-gate-title"
    title={setup?.step === 'verify' ? 'Sign in to keep going' : 'Connect Slack to start'}
    eyebrow="One more step"
    class="max-w-lg"
    backdropClass="max-md:items-end md:pl-[300px]"
  >
    <div class="px-6 pt-1 pb-6 text-center md:px-9 md:pb-8">
      {#if setup?.step === 'verify'}
        <p class="font-outfit text-sm text-ink-soft">
          Make a Hack Club account to keep your pet and your project, and to start tracking time.
        </p>
        <div class="mt-6 flex justify-center">
          <OrnateButton kind="confirm" href={signIn({ query: { login_hint: setup.email } }).url}>
            Continue with Hack Club
          </OrnateButton>
        </div>
      {:else}
        <div class="flex justify-center">
          <OrnateButton kind="confirm" href={connectSlack({ query: { return_to: page.url } }).url}>
            Connect Slack
          </OrnateButton>
        </div>
        <p class="mt-5 font-outfit text-xs text-ink-soft">
          Rather not? Skip it and Fallen's bot posts them under your name and picture. They still go to Hack
          Club Slack, so its <a
            href="https://hackclub.com/conduct/"
            target="_blank"
            rel="noopener"
            class="underline">code of conduct</a
          >
          applies. You can connect later in Settings.
        </p>
        <button
          type="button"
          class="mt-3 font-outfit text-sm text-ink-soft underline hover:text-ink"
          onclick={() => router.post(skipSlack().url, {}, { preserveScroll: true })}
          >Skip, post through the bot</button
        >
      {/if}
      <div class="mt-4 flex justify-center gap-4 font-outfit text-xs text-ink-soft">
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
  </OrnateModal>
{/if}
