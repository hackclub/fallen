<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import JoinCard from '@/components/team/JoinCard.svelte'
  import { formatMinutes } from '@/lib/format'
  import * as sfx from '@/lib/sfx'
  import { join, signIn } from '@/routes'
  import type { Project } from '@/types'

  // A project's join link. Signed out, it says whose project it is and sends them to sign in, coming back here.
  let {
    project,
    token,
    full,
    signed_in,
  }: { project: Project; token: string; full: boolean; signed_in: boolean } = $props()

  let joining = $state(false)

  function accept() {
    sfx.select()
    joining = true
    router.post(join(token).url, {}, { onFinish: () => (joining = false) })
  }
</script>

<svelte:head><title>Join {project.title} · Fallen</title></svelte:head>

<JoinCard
  title={project.title}
  description={project.description}
  bannerUrl={project.cover_url}
  teammates={project.teammates}
  {full}
>
  {#snippet headline()}
    <strong class="font-semibold text-cream">{project.teammates[0]?.name}</strong> wants you on the team.
    {#if project.journal_count > 0}
      <span class="text-sky-ice/60"
        >{formatMinutes(project.total_minutes)} logged so far over {project.journal_count}
        {project.journal_count === 1 ? 'journal' : 'journals'}.</span
      >
    {/if}
  {/snippet}

  {#if full}
    <!-- JoinCard says why. -->
  {:else if signed_in}
    <button type="button" class="pill-cream h-12 text-lg" disabled={joining} onclick={accept}
      >{joining ? 'Joining...' : 'Join the team'}</button
    >
  {:else}
    <span class="font-outfit text-sm text-sky-ice/60">Sign in first, then you'll land back here.</span>
    <a href={signIn().url} class="pill-cream h-12 text-lg">Sign in to join</a>
  {/if}
</JoinCard>
