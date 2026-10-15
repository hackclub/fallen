<script lang="ts">
  let { title, subtitle }: { title: string; subtitle?: string } = $props()
</script>

<div class="mb-8">
  <h1 class="mb-2 font-display text-4xl text-white md:text-5xl">{title}</h1>
  {#if subtitle}<p class="font-outfit text-lg text-sky-ice/60 md:text-xl">{subtitle}</p>{/if}
</div>
