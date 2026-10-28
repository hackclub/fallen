<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import ArrowRight from '@lucide/svelte/icons/arrow-right'
  import { adminUser } from '@/routes'

  // To someone's streak card on /admin/users/:id, where the week is restored.
  let { userId }: { userId: string } = $props()
</script>

<Link
  href={`${adminUser(userId).url}#streak`}
  class="inline-flex items-center gap-1 text-sm font-medium whitespace-nowrap hover:underline"
>
  Restore <ArrowRight class="size-3.5" />
</Link>
