<script lang="ts">
  import Wordmark from '@/components/Wordmark.svelte'
  import { signIn } from '@/routes'

  let { hca_configured }: { hca_configured: boolean } = $props()
</script>

<svelte:head><title>Fallen</title></svelte:head>

<section class="mx-auto max-w-2xl py-16 text-center">
  <h1 class="flex justify-center"><Wordmark class="h-16 sm:h-24" /></h1>
  <p class="mt-6 text-lg text-stone-600 dark:text-stone-400">Sign in to get started.</p>
  <div class="mt-8 flex justify-center gap-3">
    {#if hca_configured}
      <a href={signIn().url} class="btn-primary text-base">Sign in with Hack Club</a>
    {:else}
      <div class="card text-left text-sm">
        <p class="font-semibold">Hack Club Auth isn't configured yet.</p>
        <p class="mt-1 text-stone-600">
          Set <code>HCA_CLIENT_ID</code> and <code>HCA_CLIENT_SECRET</code> in <code>.env.development</code>,
          or run
          <code>bin/rails db:seed</code> and visit <code>/dev/sign_in_as/admin@example.com</code>.
        </p>
      </div>
    {/if}
  </div>
</section>
