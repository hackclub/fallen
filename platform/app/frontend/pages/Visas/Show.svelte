<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import PageTitle from '@/components/PageTitle.svelte'
  import VisaChecker from '@/components/VisaChecker.svelte'
</script>

<svelte:head><title>Visa · Fallen</title></svelte:head>

<PageTitle title="Visa" />

<div class="max-w-2xl space-y-4 font-outfit text-base leading-relaxed text-pale-blue">
  <VisaChecker />
  <p class="px-1 text-sm text-pale-blue/80">
    Not sure your situation fits? Email
    <a
      href="mailto:fallen@hackclub.com"
      class="text-cream underline decoration-cream/40 underline-offset-3 hover:decoration-cream"
      >fallen@hackclub.com</a
    >.
  </p>
</div>
