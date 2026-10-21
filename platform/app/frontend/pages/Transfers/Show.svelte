<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import PageTitle from '@/components/PageTitle.svelte'
</script>

<svelte:head><title>Transfers · Fallen</title></svelte:head>

<PageTitle title="Transfers" />

<section class="flex flex-col items-start gap-6">
  <p class="font-outfit text-lg text-white">You can do project transfers in this form.</p>
  <a href="https://forms.hackclub.com/ballen" target="_blank" rel="noopener" class="btn-primary text-base">
    Open the form
  </a>
</section>
