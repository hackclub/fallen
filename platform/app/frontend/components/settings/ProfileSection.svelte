<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import { signOut } from '@/routes'
  import type { User } from '@/types'

  let { user, timezone }: { user: User; timezone?: string } = $props()
</script>

<SettingRow title={user.display_name} description="Your name and picture come from your Slack profile.">
  {#snippet lead()}
    <img
      src={user.avatar}
      alt=""
      class="size-14 rounded-full object-cover ring-2 ring-cream/70 ring-offset-2 ring-offset-transparent"
    />
  {/snippet}
</SettingRow>
<SettingRow
  title="Timezone"
  description="Set from your browser. The days your journals count toward are in this timezone."
>
  <span class="font-montserrat font-semibold text-cream">{timezone ?? '…'}</span>
</SettingRow>
<SettingRow title="Sign out" description="Sign out of Fallen in this browser.">
  <button type="button" class="pill-glass" onclick={() => router.visit(signOut())}>Sign out</button>
</SettingRow>
