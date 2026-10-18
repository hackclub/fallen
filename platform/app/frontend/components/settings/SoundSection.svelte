<script lang="ts">
  import SettingRow from '@/components/settings/SettingRow.svelte'
  import VolumeBar from '@/components/settings/VolumeBar.svelte'
  import { preferences, setPreference } from '@/lib/preferences.svelte'
</script>

<SettingRow
  title="Volume"
  description="Menu sounds and the hatch. Use the arrow keys or drag across the bars."
>
  <VolumeBar label="Volume" value={preferences.volume} onchange={(v) => setPreference('volume', v)} />
</SettingRow>
