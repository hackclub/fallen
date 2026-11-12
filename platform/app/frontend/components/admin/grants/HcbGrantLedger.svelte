<script lang="ts">
  import { money } from '@/lib/submission'
  import type { AdminHcbOrgGrant } from '@/types'

  let { grant }: { grant: AdminHcbOrgGrant } = $props()
</script>

{#if grant.ignored}
  <span class="text-xs text-muted-foreground"
    >Not counted{grant.ignored_by ? ` (${grant.ignored_by.name})` : ''}</span
  >
{:else if !grant.person}
  <span class="text-xs font-medium text-amber-600">No Fallen account has this email</span>
{:else if grant.ledger}
  <span class="text-xs font-medium text-red-600"
    >HCB {money(grant.ledger.hcb_cents)}, Fallen sent {money(grant.ledger.fallen_cents)}</span
  >
{:else}
  <span class="text-xs text-emerald-600">Matches</span>
{/if}
