<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import { Button } from '@/components/admin/ui/button'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import * as Dialog from '@/components/admin/ui/dialog'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { Textarea } from '@/components/admin/ui/textarea'
  import { REASONS, daysBetween, plural, rangeLabel } from '@/lib/streaks'
  import { adminStreakAdjustments } from '@/routes'

  type IncidentPreview = {
    errors: string[]
    weeks?: number
    missed?: number
    broken?: number
    lulu?: number
  }

  // Excuses days for everyone, for when something on our side kept people from journaling. Its reach is shown
  // before it is made, from the page's optional `incident_preview` prop; the exact count lands on it as the
  // background jobs judge each person again.
  let { open = $bindable() }: { open: boolean } = $props()

  const today = new Date().toISOString().slice(0, 10)
  let form = $state({ starts_on: today, ends_on: today, reason: '', reprice: true })
  let preview = $state<IncidentPreview>()
  let loading = $state(false)
  let saving = $state(false)
  let errors = $state<Record<string, string>>({})
  let confirmed = $state(false)

  const days = $derived(
    form.starts_on && form.ends_on ? Math.max(daysBetween(form.starts_on, form.ends_on) + 1, 0) : 0,
  )

  $effect(() => {
    if (!open) return
    const data = { preview: { starts_on: form.starts_on, ends_on: form.ends_on, reprice: form.reprice } }
    loading = true
    confirmed = false
    const timer = setTimeout(() => {
      router.reload({
        only: ['incident_preview'],
        data,
        onSuccess: (page) => (preview = page.props.incident_preview as IncidentPreview),
        onFinish: () => (loading = false),
      })
    }, 250)
    return () => clearTimeout(timer)
  })

  function submit(event: SubmitEvent) {
    event.preventDefault()
    router.post(
      adminStreakAdjustments.create(),
      { adjustment: { kind: 'excuse', ...form } },
      {
        preserveScroll: true,
        onStart: () => (saving = true),
        onFinish: () => (saving = false),
        onSuccess: () => {
          open = false
          form = { starts_on: today, ends_on: today, reason: '', reprice: true }
        },
        onError: (failed) => (errors = failed),
      },
    )
  }
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="max-h-[90vh] overflow-y-auto sm:max-w-lg">
    <form onsubmit={submit} class="contents">
      <Dialog.Header>
        <Dialog.Title>New incident</Dialog.Title>
        <Dialog.Description>
          The days count as journaled for everyone's streak and Lulu bonus. Each day is each person's own
          calendar day, so an outage late in UTC may need the next day too.
        </Dialog.Description>
      </Dialog.Header>

      <div class="grid gap-4">
        <div class="grid grid-cols-2 gap-3">
          <div class="grid gap-1.5">
            <Label for="incident-from">From</Label>
            <Input id="incident-from" type="date" bind:value={form.starts_on} />
          </div>
          <div class="grid gap-1.5">
            <Label for="incident-to">To</Label>
            <Input id="incident-to" type="date" bind:value={form.ends_on} min={form.starts_on} />
          </div>
        </div>

        <div class="grid gap-1.5">
          <Label for="incident-reason">What happened</Label>
          <Textarea
            id="incident-reason"
            bind:value={form.reason}
            rows={2}
            placeholder="Shown to staff only"
          />
          <div class="flex flex-wrap gap-1.5">
            {#each REASONS.slice(0, 3) as reason (reason)}
              <button
                type="button"
                class="cursor-pointer rounded-full border border-border px-2.5 py-0.5 text-xs text-muted-foreground transition-colors hover:border-foreground/40 hover:text-foreground"
                onclick={() => (form.reason = reason)}>{reason}</button
              >
            {/each}
          </div>
          {#if errors.reason}<p class="text-sm text-destructive">Reason {errors.reason}</p>{/if}
        </div>

        <Label class="flex items-start gap-2 font-normal">
          <Checkbox
            checked={form.reprice}
            onCheckedChange={(checked) => (form.reprice = checked)}
            class="mt-0.5"
          />
          <span>
            Re-count journals saved at a multiplier that changes
            <span class="block text-xs text-muted-foreground"
              >So restored streaks pay for the days since too.</span
            >
          </span>
        </Label>

        <div
          class={['rounded-lg border bg-muted/30 p-3 text-sm', loading && 'opacity-60']}
          aria-live="polite"
        >
          <div
            class="mb-2 flex items-center gap-1.5 text-xs font-medium tracking-wide text-muted-foreground uppercase"
          >
            Reach {#if loading}<LoaderCircle class="size-3 animate-spin" />{/if}
          </div>
          {#if preview?.errors.length}
            {#each preview.errors as error (error)}
              <p class="flex gap-1.5 text-destructive">
                <CircleAlert class="mt-0.5 size-4 shrink-0" />{error}
              </p>
            {/each}
          {:else if preview}
            <ul class="space-y-1">
              <li>
                {plural(preview.weeks ?? 0, 'judged Team Sami week')} hold these days;
                <span class="font-medium">{preview.missed ?? 0}</span> missed days in them and
                <span class="font-medium text-destructive">{preview.broken ?? 0}</span> broke.
              </li>
              <li>{plural(preview.lulu ?? 0, 'Team Lulu member')} checked for a bonus the days would pay.</li>
              <li class="text-muted-foreground">Weeks not judged yet count the days when they close.</li>
            </ul>
          {:else}
            <p class="text-muted-foreground">Working it out…</p>
          {/if}
        </div>

        {#if errors.base}<p class="text-sm text-destructive">{errors.base}</p>{/if}

        <Label class="flex items-start gap-2 font-normal">
          <Checkbox checked={confirmed} onCheckedChange={(checked) => (confirmed = checked)} class="mt-0.5" />
          <span>
            Excuse {days > 0 && form.starts_on && form.ends_on
              ? rangeLabel(form.starts_on, form.ends_on)
              : 'these days'}
            for everyone
          </span>
        </Label>
      </div>

      <Dialog.Footer>
        <Button type="button" variant="outline" onclick={() => (open = false)}>Cancel</Button>
        <Button
          type="submit"
          disabled={saving || !confirmed || !form.reason.trim() || Boolean(preview?.errors.length)}
        >
          Make incident
        </Button>
      </Dialog.Footer>
    </form>
  </Dialog.Content>
</Dialog.Root>
