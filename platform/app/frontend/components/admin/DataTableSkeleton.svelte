<script lang="ts">
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import * as Table from '@/components/admin/ui/table'

  // Stands in for DataTable while deferred rows load. Same shell, so nothing shifts when they arrive.
  // `avatar` matches a first column with an avatar, a name and a second line.
  let {
    headers,
    rows = 10,
    avatar = false,
  }: { headers: string[]; rows?: number; avatar?: boolean } = $props()
</script>

<div>
  <div class="overflow-hidden rounded-md border border-border">
    <Table.Root>
      <Table.Header>
        <Table.Row>
          {#each headers as header (header)}<Table.Head>{header}</Table.Head>{/each}
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {#each { length: rows }, r (r)}
          <Table.Row>
            {#each headers as header, c (header)}
              <Table.Cell>
                {#if avatar && c === 0}
                  <div class="flex items-center gap-2.5">
                    <Skeleton class="size-7 shrink-0 rounded-full" />
                    <div class="space-y-2">
                      <Skeleton class="h-4 w-28" />
                      <Skeleton class="h-3 w-36" />
                    </div>
                  </div>
                {:else}
                  <div class="flex h-5 items-center">
                    <Skeleton class="h-4" style="width: {55 + ((r * 7 + c * 13) % 40)}%" />
                  </div>
                {/if}
              </Table.Cell>
            {/each}
          </Table.Row>
        {/each}
      </Table.Body>
    </Table.Root>
  </div>
  <div class="pt-4"><Skeleton class="h-4 w-32" /></div>
</div>
