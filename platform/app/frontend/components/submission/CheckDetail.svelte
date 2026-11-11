<script lang="ts">
  import type { Check } from '@/lib/submission'
  import { docs } from '@/routes'

  let { check }: { check: Pick<Check, 'detail' | 'doc'> } = $props()

  const parts = $derived(check.doc ? (check.detail ?? '').match(/^(.*?)\[([^\]]+)\](.*)$/s) : null)
</script>

{#if parts && check.doc}{parts[1]}<a
    href={docs.show({ page: check.doc }).url}
    target="_blank"
    class="font-semibold underline underline-offset-2">{parts[2]}</a
  >{parts[3]}{:else}{check.detail}{/if}
