<script lang="ts">
  import type { Snippet } from 'svelte'
  import { Link, router } from '@inertiajs/svelte'
  import Flash from '@/components/Flash.svelte'
  import ImpersonationBanner from '@/components/ImpersonationBanner.svelte'
  import { adminRoot, home, projects, signOut } from '@/routes'
  import { shared } from '@/lib/shared.svelte'
  import logo from '@/assets/sky/logo.png'
  import flowers from '@/assets/sky/flowers.png'

  let { children }: { children?: Snippet } = $props()

  const user = $derived(shared().auth.user)
</script>

<div class="relative flex min-h-screen flex-col overflow-x-clip bg-sky-deep text-white">
  <div class="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
    <!-- Offset upward so the wordmark painted into the artwork sits above the viewport. -->
    <img
      src={flowers}
      alt=""
      class="absolute top-[-14vw] left-1/2 w-[160%] max-w-none -translate-x-1/2 opacity-30 sm:w-[120%]"
    />
    <div class="absolute inset-0 bg-linear-to-b from-transparent via-sky-deep/70 to-sky-night"></div>
  </div>

  <div class="relative z-10 flex min-h-screen flex-col">
    <ImpersonationBanner />

    {#if user}
      <header class="border-b border-white/10">
        <nav class="mx-auto flex h-14 max-w-5xl items-center justify-between px-4 sm:px-6">
          <Link href={home.index()} class="flex items-center">
            <img src={logo} alt="Fallen" class="h-8 w-auto" />
          </Link>

          <div class="flex items-center gap-3 font-outfit text-sm">
            <Link href={projects.index()} class="text-sky-ice/70 hover:text-white">Projects</Link>
            {#if user.is_admin}
              <Link href={adminRoot()} class="text-sky-ice/70 hover:text-white">Admin</Link>
            {/if}
            <span class="hidden items-center gap-2 sm:flex">
              <img src={user.avatar} alt="" class="h-7 w-7 rounded-full bg-sky-night object-cover" />
              <span class="font-medium">{user.display_name}</span>
            </span>
            <button type="button" onclick={() => router.visit(signOut())} class="btn-sky px-3 py-1.5">
              Sign out
            </button>
          </div>
        </nav>
      </header>
    {/if}

    <main class="mx-auto w-full max-w-5xl flex-1 px-4 py-8 sm:px-6">
      <Flash />
      {@render children?.()}
    </main>

    <footer class="py-6 text-center font-outfit text-xs text-sky-ice/50">
      <a href="https://hackclub.com" class="hover:text-white">Hack Club</a>
    </footer>
  </div>
</div>
