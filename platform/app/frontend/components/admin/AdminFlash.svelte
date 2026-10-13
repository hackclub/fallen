<script lang="ts">
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import * as Alert from '@/components/admin/ui/alert'
  import { shared } from '@/lib/shared.svelte'

  const flash = $derived(shared().flash ?? {})
</script>

{#if flash.notice}
  <Alert.Root class="mb-4">
    <CircleCheck />
    <Alert.Title>{flash.notice}</Alert.Title>
  </Alert.Root>
{/if}
{#if flash.alert}
  <Alert.Root variant="destructive" class="mb-4">
    <CircleAlert />
    <Alert.Title>{flash.alert}</Alert.Title>
  </Alert.Root>
{/if}
