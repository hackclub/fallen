<script lang="ts">
  let { value, class: className = '' }: { value: string | number; class?: string } = $props()

  const chars = $derived(String(value).split(''))
</script>

<!-- Each change re-mounts the digits, which replays the t-digit-pop-in animation from admin.css. -->
{#key value}
  <span class="t-digit-group is-animating {className}">
    {#each chars as char, i (i)}
      <span class="t-digit" data-stagger={i > 0 && i <= 3 ? i : undefined}>{char}</span>
    {/each}
  </span>
{/key}
