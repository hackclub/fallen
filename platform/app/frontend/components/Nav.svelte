<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { adminRoot, home, root, signIn, signOut } from '@/routes'
  import { shared } from '@/lib/shared.svelte'

  const user = $derived(shared().auth.user)
</script>

<header class="border-b border-stone-200 bg-white dark:border-stone-800 dark:bg-stone-900">
  <nav class="mx-auto flex h-14 max-w-5xl items-center justify-between px-4 sm:px-6">
    <Link href={user ? home.index() : root()} class="flex items-center">
      <Wordmark class="h-5" />
    </Link>

    <div class="flex items-center gap-3 text-sm">
      {#if user}
        {#if user.is_admin}
          <Link
            href={adminRoot()}
            class="text-stone-600 hover:text-stone-900 dark:text-stone-300 dark:hover:text-white">Admin</Link
          >
        {/if}
        <span class="hidden items-center gap-2 sm:flex">
          <img src={user.avatar} alt="" class="h-7 w-7 rounded-full bg-stone-200 object-cover" />
          <span class="font-medium">{user.display_name}</span>
        </span>
        <button type="button" onclick={() => router.visit(signOut())} class="btn-secondary px-3 py-1.5"
          >Sign out</button
        >
      {:else}
        <a href={signIn().url} class="btn-primary px-3 py-1.5">Sign in with Hack Club</a>
      {/if}
    </div>
  </nav>
</header>
