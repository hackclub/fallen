<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { adminProject } from '@/routes'
  import type { AdminProject } from '@/types'

  let { project }: { project: AdminProject } = $props()
</script>

<Link href={adminProject(project.id)} prefetch cacheFor="30s" class="group block min-w-0">
  <span class="flex items-center gap-1.5 font-medium group-hover:underline">
    {project.title}
    {#if project.discarded_at}<Badge variant="destructive" class="text-[10px]">Deleted</Badge>{/if}
  </span>
  {#if project.description}
    <span class="block max-w-md truncate text-xs text-muted-foreground">{project.description}</span>
  {/if}
</Link>
