<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { Button } from '@/components/admin/ui/button'
  import { adminHcbGrant } from '@/routes'
  import type { AdminHcbOrgGrant } from '@/types'

  let { grant }: { grant: AdminHcbOrgGrant } = $props()

  const toggle = () =>
    router.patch(adminHcbGrant(grant.id).url, { ignored: !grant.ignored }, { preserveScroll: true })
</script>

<div class="flex flex-wrap justify-end gap-1.5">
  <Button size="sm" variant="ghost" href={grant.url} target="_blank" rel="noopener">Open on HCB</Button>
  <Button
    size="sm"
    variant="ghost"
    title={grant.ignored
      ? 'Count this grant towards what its person has been paid again'
      : 'For a grant that isn’t design funding: it stops counting towards what its person has been paid'}
    onclick={toggle}>{grant.ignored ? 'Count it' : 'Not design funding'}</Button
  >
</div>
