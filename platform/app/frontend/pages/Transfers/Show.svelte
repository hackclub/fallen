<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import PageTitle from '@/components/PageTitle.svelte'
  import SolarTransfer from '@/components/icons/SolarTransfer.svelte'
</script>

<svelte:head><title>Transfers · Fallen</title></svelte:head>

<PageTitle title="Transfers" />

<section class="relative isolate min-h-[640px] md:h-[calc(100dvh-14rem)]">
  <div class="absolute inset-0 flex flex-col items-center justify-center gap-4 px-6 text-center">
    <SolarTransfer size={56} class="text-white drop-shadow-[0_2px_12px_rgb(0_0_0/0.5)]" />
    <p
      class="max-w-lg font-montserrat text-2xl md:text-3xl font-semibold tracking-[-0.02em] text-white drop-shadow-[0_2px_12px_rgb(0_0_0/0.5)]"
    >
      You can do project transfers in this form.
    </p>
    <a
      href="https://forms.hackclub.com/ballen"
      target="_blank"
      rel="noopener"
      class="pill-cream mt-2 h-12 px-6 text-lg"
    >
      Open the form
    </a>
  </div>
</section>
