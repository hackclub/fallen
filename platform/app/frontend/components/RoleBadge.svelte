<script lang="ts">
  let { role }: { role: string } = $props()

  const styles: Record<string, string> = {
    admin: 'bg-hc-red/10 text-hc-red',
    reviewer: 'bg-hc-blue/10 text-hc-blue',
    user: 'bg-stone-100 text-stone-700',
  }
</script>

<span class="badge {styles[role] ?? styles.user}">{role}</span>
