<script lang="ts">
  import { onMount, type Snippet } from 'svelte'
  import { Link, page } from '@inertiajs/svelte'
  import Toaster from '@/components/Toaster.svelte'
  import OnboardingOverlay from '@/components/onboarding/OnboardingOverlay.svelte'
  import HatchOverlay from '@/components/hatch/HatchOverlay.svelte'
  import SlackGate from '@/components/onboarding/SlackGate.svelte'
  import DesktopPet from '@/components/DesktopPet.svelte'
  import ImpersonationBanner from '@/components/ImpersonationBanner.svelte'
  import NavRail from '@/components/NavRail.svelte'
  import NameTag from '@/components/NameTag.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { adminRoot, home, signIn } from '@/routes'
  import { shared } from '@/lib/shared.svelte'
  import { slackGateDue } from '@/lib/slackGate.svelte'
  import { pages, warmPages } from '@/lib/pages'
  import sky from '@/assets/hero/starry-bg.webp'
  import building from '@/assets/hero/building-1.webp'

  let { children }: { children?: Snippet } = $props()

  const user = $derived(shared().auth.user)
  // Someone only checking the docs reads them first, and someone sent a team's link or invite joins it first, so the
  // onboarding knows not to ask them for a project. It greets them on the next page.
  const holdOnboarding = $derived(
    ['Docs/Show', 'ProjectJoins/Show', 'ProjectInvites/Show'].includes(page.component),
  )
  // While the Slack gate is up the rail sits above its backdrop, so the docs and project pages stay reachable.
  const gated = $derived(slackGateDue())

  onMount(warmPages)
</script>

<div class="relative min-h-screen overflow-x-clip bg-sky-deep text-white">
  <img
    src={sky}
    alt=""
    aria-hidden="true"
    class="pointer-events-none fixed inset-0 h-full w-full object-cover"
  />

  <div class="relative z-10 flex min-h-screen flex-col">
    <ImpersonationBanner />

    <div class="relative flex flex-1 flex-col md:flex-row">
      <!-- Rail: logo, nav and the name tag, pinned while the page scrolls. Offsets are the Figma frame's. -->
      <aside
        class={[
          'relative flex flex-col gap-6 px-4 pt-6 md:sticky md:top-0 md:h-dvh md:w-[300px] md:shrink-0 md:gap-0 md:px-0 md:pt-[37px] md:pb-[42px]',
          gated && 'z-[60]',
        ]}
      >
        <img
          src={building}
          alt=""
          aria-hidden="true"
          class="pointer-events-none absolute -top-[88px] -left-[167px] w-[403px] max-w-none md:-top-[136px] md:-left-[257px] md:w-[620px]"
        />

        <Link href={home.index()} component={pages.home} class="relative w-fit md:ml-[53px]">
          <Wordmark onDark class="h-[65px] md:h-[89px]" />
        </Link>

        {#if user}
          <NavRail class="relative w-fit md:mt-10 md:ml-[53px] md:w-[204px]" />
          <NameTag {user} class="mt-auto ml-[67px] hidden md:block" />
        {:else}
          <!-- Signed out (only Docs is public): signing in where the name tag would be. A full visit, it leaves for
               Hack Club Auth. -->
          <a href={signIn().url} class="pill-cream relative mt-auto ml-[67px] hidden w-fit md:inline-flex"
            >Sign in</a
          >
        {/if}
      </aside>

      <div class="flex min-w-0 flex-1 flex-col">
        {#if user?.is_admin}
          <div class="absolute top-6 right-4 md:static md:flex md:justify-end md:pt-[51px] md:pr-[59px]">
            <Link href={adminRoot()} class="pill-cream">Admin</Link>
          </div>
        {/if}

        <main
          class="mx-auto w-full max-w-5xl flex-1 has-[[data-wide]]:max-w-[1360px] px-4 py-8 md:pr-[59px] md:pl-0"
        >
          <Toaster />
          <DesktopPet />
          <OnboardingOverlay greet={!holdOnboarding} />
          <HatchOverlay />
          <SlackGate />
          {@render children?.()}
        </main>

        {#if user}
          <NameTag {user} class="mx-4 mb-8 md:hidden" />
        {:else}
          <a href={signIn().url} class="pill-cream mx-4 mb-8 w-fit md:hidden">Sign in</a>
        {/if}
      </div>
    </div>
  </div>
</div>
