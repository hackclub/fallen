<script lang="ts">
  import { Badge } from '@/components/admin/ui/badge'

  let { roles }: { roles: string[] } = $props()
</script>

<div class="flex flex-wrap gap-1">
  {#each roles as role (role)}
    <Badge variant={role === 'admin' ? 'default' : 'outline'} class="text-[10px]">{role}</Badge>
  {/each}
</div>
