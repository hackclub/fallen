<script lang="ts">
  import { page, router } from '@inertiajs/svelte'
  import { fade } from 'svelte/transition'
  import SlackConnect from '@/components/SlackConnect.svelte'
  import { shared } from '@/lib/shared.svelte'
  import { tour } from '@/lib/tour.svelte'
  import { signOut } from '@/routes'

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
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/45 p-4"
    transition:fade={{ duration: 200 }}
    {@attach portal}
  >
    <div class="w-full max-w-md" role="dialog" aria-modal="true" aria-label="Connect Slack">
      <SlackConnect
        slack={{ configured: true, oauth_available: true, connected: false, linked: false }}
        returnTo={page.url}
      />
      <button
        type="button"
        class="mt-3 w-full text-center font-outfit text-xs text-white/70 underline hover:text-white"
        onclick={() => router.visit(signOut())}>Sign out</button
      >
    </div>
  </div>
{/if}
