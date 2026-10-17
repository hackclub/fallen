<script lang="ts">
  import { page, router } from '@inertiajs/svelte'
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import { shared } from '@/lib/shared.svelte'
  import { tour } from '@/lib/tour.svelte'
  import { connectSlack, devSkipSlack, signOut } from '@/routes'

  // After the onboarding, Slack: journals are posted as the person, so until it is connected there is nothing else
  // to do. The server only asks for this when Slack sign-in is set up (ApplicationController#setup_props). Comes
  // back to the same page. A project's own pages are let through: the onboarding ends on one, and they explain Slack
  // in place.
  const PROJECT_PAGES = ['Projects/Show', 'Projects/Form']
  const due = $derived(
    shared().setup?.step === 'slack' && !tour.open && !PROJECT_PAGES.includes(page.component),
  )

  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

{#if due}
  <div {@attach portal}>
    <OrnateModal
      titleId="slack-gate-title"
      title="Connect Slack to start"
      eyebrow="One more step"
      class="max-w-lg"
    >
      <div class="px-6 pt-1 pb-6 text-center md:px-9 md:pb-8">
        <p class="font-outfit text-sm text-ink-soft">
          Your project lives as a thread in the journals channel and every journal is a reply in it, posted as
          you.
        </p>
        <div class="mt-6 flex justify-center">
          <OrnateButton kind="confirm" href={connectSlack({ query: { return_to: page.url } }).url}>
            Connect Slack
          </OrnateButton>
        </div>
        <div class="mt-4 flex justify-center gap-4 font-outfit text-xs text-ink-soft">
          <button type="button" class="underline hover:text-ink" onclick={() => router.visit(signOut())}
            >Sign out</button
          >
          {#if import.meta.env.DEV}
            <button
              type="button"
              class="underline hover:text-ink"
              onclick={() => router.post(devSkipSlack().url, {}, { preserveScroll: true })}>Skip (dev)</button
            >
          {/if}
        </div>
      </div>
    </OrnateModal>
  </div>
{/if}
