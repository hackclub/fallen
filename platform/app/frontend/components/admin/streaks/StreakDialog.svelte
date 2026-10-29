<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { untrack } from 'svelte'
  import Minus from '@lucide/svelte/icons/minus'
  import Plus from '@lucide/svelte/icons/plus'
  import StreakPreviewPanel from '@/components/admin/streaks/StreakPreviewPanel.svelte'
  import { Button } from '@/components/admin/ui/button'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import * as Dialog from '@/components/admin/ui/dialog'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { Switch } from '@/components/admin/ui/switch'
  import { Textarea } from '@/components/admin/ui/textarea'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import {
    REASONS,
    daysBetween,
    formatMultiplier,
    plural,
    rangeLabel,
    type StreakFields,
    type StreakKind,
    type StreakPreview,
  } from '@/lib/streaks'
  import { adminStreakAdjustments } from '@/routes'
  import type { AdminStreak, AdminUserDetail } from '@/types'

  // Excusing days, giving or taking freezes or XP, or setting the streak outright, with a live preview of what it does.
  // The preview is the page's optional `streak_preview` prop, asked for again as the fields change and kept here.
  let {
    open = $bindable(),
    kind,
    range,
    user,
    streak,
    onSaved,
  }: {
    open: boolean
    kind: StreakKind
    range: { from: string; to: string } | null
    user: AdminUserDetail
    streak: AdminStreak
    onSaved?: () => void
  } = $props()

  const blank = () => ({
    starts_on: range?.from ?? streak.today,
    ends_on: range?.to ?? streak.today,
    freezes: kind === 'set' ? streak.freezes : 1,
    multiplier: streak.multiplier,
    xp: 10,
    reason: '',
    message: '',
    notify: false,
    reprice: true,
  })

  // svelte-ignore state_referenced_locally
  let form = $state(blank())
  let errors = $state<Record<string, string>>({})
  let loading = $state(false)
  let saving = $state(false)
  let shown = $state<StreakPreview | undefined>()

  const sami = $derived(streak.team === 'sami')
  const days = $derived(
    form.starts_on && form.ends_on ? Math.max(daysBetween(form.starts_on, form.ends_on) + 1, 0) : 0,
  )
  // What changes the outcome; the reason and the DM don't, so typing them asks for no new preview.
  const change = $derived({
    kind,
    reprice: form.reprice,
    ...(kind === 'excuse' && { starts_on: form.starts_on, ends_on: form.ends_on }),
    ...(kind === 'freezes' && { freezes: form.freezes }),
    ...(kind === 'set' && { freezes: form.freezes, multiplier: form.multiplier }),
    ...(kind === 'xp' && { xp: form.xp }),
  })
  const fields = $derived<StreakFields>({
    ...change,
    reason: form.reason,
    message: form.message,
    notify: form.notify,
  })
  const title = $derived(
    kind === 'excuse'
      ? `Excuse ${form.starts_on && form.ends_on ? rangeLabel(form.starts_on, form.ends_on) : 'days'}`
      : kind === 'freezes'
        ? 'Give or take freezes'
        : kind === 'xp'
          ? 'Give or take XP'
          : 'Set the streak',
  )
  const action = $derived(
    kind === 'excuse'
      ? `Excuse ${plural(days, 'day')}`
      : kind === 'freezes'
        ? `${form.freezes >= 0 ? 'Give' : 'Take'} ${plural(Math.abs(form.freezes), 'freeze')}`
        : kind === 'xp'
          ? `${form.xp >= 0 ? 'Give' : 'Take'} ${Math.abs(form.xp)} XP`
          : 'Set streak',
  )
  const blocked = $derived(
    saving ||
      !form.reason.trim() ||
      (kind === 'freezes' && form.freezes === 0) ||
      (kind === 'xp' && !form.xp) ||
      Boolean(shown?.errors.length),
  )

  // A fresh form each time it opens, for the days picked on the calendar. Only opening resets it: the props it
  // reads change identity on every preview, which would wipe what the admin typed.
  $effect(() => {
    if (!open) return
    untrack(() => {
      form = blank()
      errors = {}
      shown = undefined
    })
  })

  // Asks for the preview a moment after the fields stop changing. Each reload cancels the one before, so answers
  // never arrive out of order.
  $effect(() => {
    if (!open) return
    const data = { preview: change }
    loading = true
    const timer = setTimeout(() => {
      router.reload({
        only: ['streak_preview'],
        data,
        onSuccess: (page) => (shown = page.props.streak_preview as StreakPreview),
        onFinish: () => (loading = false),
      })
    }, 250)
    return () => clearTimeout(timer)
  })

  function submit(event: SubmitEvent) {
    event.preventDefault()
    router.post(
      adminStreakAdjustments.create(),
      { adjustment: { ...fields, user_id: user.id } },
      {
        preserveScroll: true,
        onStart: () => (saving = true),
        onFinish: () => (saving = false),
        onSuccess: () => {
          open = false
          onSaved?.()
        },
        onError: (failed) => (errors = failed),
      },
    )
  }
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="max-h-[90vh] overflow-y-auto sm:max-w-xl">
    <form onsubmit={submit} class="contents">
      <Dialog.Header>
        <Dialog.Title>{title}</Dialog.Title>
        <Dialog.Description>
          {#if kind === 'excuse'}
            Excused days count as journaled for {user.display_name}'s {sami ? 'streak' : 'weekly bonus'}.
            Weeks already judged are judged again; open ones count them when they close.
          {:else if kind === 'freezes'}
            Freezes cover missed days from now on. To save a week that already broke, excuse its days instead.
          {:else if kind === 'xp'}
            Added to {user.display_name}'s XP as its own line, for anything their journals didn't earn. It
            doesn't count in the team race.
          {:else}
            For anything an excuse or freezes don't cover. Set values carry on from here as if earned.
          {/if}
        </Dialog.Description>
      </Dialog.Header>

      <div class="grid gap-4">
        {#if kind === 'excuse'}
          <div class="grid grid-cols-2 gap-3">
            <div class="grid gap-1.5">
              <Label for="streak-from">From</Label>
              <Input id="streak-from" type="date" bind:value={form.starts_on} />
            </div>
            <div class="grid gap-1.5">
              <Label for="streak-to">To</Label>
              <Input id="streak-to" type="date" bind:value={form.ends_on} min={form.starts_on} />
            </div>
          </div>
          {#if days > streak.rules.max_excuse_days}
            <p class="-mt-2 text-xs text-destructive">
              At most {streak.rules.max_excuse_days} days at a time. Make a second excuse for the rest.
            </p>
          {:else}
            <p class="-mt-2 text-xs text-muted-foreground">
              {plural(days, 'day')} on their calendar ({user.timezone}). Days they journaled are left as they
              are.
            </p>
          {/if}
        {/if}

        {#if kind === 'set' && sami}
          <div class="grid gap-1.5">
            <Label>Multiplier</Label>
            <ToggleGroup.Root
              type="single"
              variant="outline"
              size="sm"
              value={String(form.multiplier)}
              onValueChange={(value) => value && (form.multiplier = Number(value))}
              class="flex-wrap"
            >
              {#each streak.rules.multipliers as multiplier (multiplier)}
                <ToggleGroup.Item value={String(multiplier)} class="px-3 tabular-nums"
                  >{formatMultiplier(multiplier)}</ToggleGroup.Item
                >
              {/each}
            </ToggleGroup.Root>
            <p class="text-xs text-muted-foreground">
              A week kept adds {streak.rules.step.toFixed(2)}, up to {formatMultiplier(
                streak.rules.multipliers.at(-1) ?? 1,
              )}.
            </p>
          </div>
        {:else if kind === 'set'}
          <p class="text-sm text-muted-foreground">
            The multiplier only counts on Team Sami, so only freezes can be set for {user.display_name}.
          </p>
        {/if}

        {#if kind === 'xp'}
          <div class="grid gap-1.5">
            <Label for="streak-xp">XP to give</Label>
            <div class="flex items-center gap-2">
              <Input
                id="streak-xp"
                type="number"
                class="w-24 text-center tabular-nums"
                bind:value={form.xp}
              />
              <span class="text-sm text-muted-foreground tabular-nums">
                {user.xp} now, {user.xp + (form.xp || 0)} after
              </span>
            </div>
            <p class="text-xs text-muted-foreground">
              A negative number takes XP back. At most {streak.rules.max_xp} at a time.
            </p>
            {#if errors.xp}<p class="text-sm text-destructive">XP {errors.xp}</p>{/if}
          </div>
        {/if}

        {#if kind === 'freezes' || kind === 'set'}
          <div class="grid gap-1.5">
            <Label for="streak-freezes">{kind === 'set' ? 'Freezes' : 'Freezes to give'}</Label>
            <div class="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="icon"
                aria-label="One fewer"
                disabled={kind === 'set' ? form.freezes <= 0 : streak.freezes + form.freezes <= 0}
                onclick={() => form.freezes--}><Minus /></Button
              >
              <Input
                id="streak-freezes"
                type="number"
                class="w-20 text-center tabular-nums"
                bind:value={form.freezes}
              />
              <Button
                type="button"
                variant="outline"
                size="icon"
                aria-label="One more"
                disabled={(kind === 'set' ? form.freezes : streak.freezes + form.freezes) >=
                  streak.rules.max_freezes}
                onclick={() => form.freezes++}><Plus /></Button
              >
              {#if kind === 'freezes'}
                <span class="text-sm text-muted-foreground tabular-nums">
                  {streak.freezes} now, {streak.freezes + form.freezes} after
                </span>
              {/if}
            </div>
            {#if kind === 'freezes'}
              <p class="text-xs text-muted-foreground">A negative number takes freezes back.</p>
            {/if}
            {#if errors.freezes}<p class="text-sm text-destructive">Freezes {errors.freezes}</p>{/if}
          </div>
        {/if}

        <div class="grid gap-1.5">
          <Label for="streak-reason">Why</Label>
          <Textarea
            id="streak-reason"
            bind:value={form.reason}
            rows={2}
            placeholder="Staff only. Shown in the log on this page and /admin/streaks."
          />
          <div class="flex flex-wrap gap-1.5">
            {#each REASONS as reason (reason)}
              <button
                type="button"
                class={[
                  'cursor-pointer rounded-full border px-2.5 py-0.5 text-xs transition-colors',
                  form.reason === reason
                    ? 'border-foreground bg-foreground text-background'
                    : 'border-border text-muted-foreground hover:border-foreground/40 hover:text-foreground',
                ]}
                onclick={() => (form.reason = reason)}>{reason}</button
              >
            {/each}
          </div>
          {#if errors.reason}<p class="text-sm text-destructive">Reason {errors.reason}</p>{/if}
        </div>

        {#if (kind === 'excuse' || kind === 'set') && sami}
          <Label class="flex items-start gap-2 font-normal">
            <Checkbox
              checked={form.reprice}
              onCheckedChange={(checked) => (form.reprice = checked)}
              class="mt-0.5"
            />
            <span>
              Re-count journals saved at the old multiplier
              <span class="block text-xs text-muted-foreground">
                Each journal keeps the multiplier it was saved with, so without this the change only counts
                from now on.
              </span>
            </span>
          </Label>
        {/if}

        <div class="grid gap-2 rounded-lg border p-3">
          <Label class="flex items-center justify-between gap-3 font-normal">
            <span>
              Tell them in a Slack DM
              <span class="block text-xs text-muted-foreground">
                {user.slack_id
                  ? 'What changed and their new numbers, with your note if you write one.'
                  : "They haven't linked Slack, so there's nowhere to DM."}
              </span>
            </span>
            <Switch
              checked={form.notify}
              onCheckedChange={(checked) => (form.notify = checked)}
              disabled={!user.slack_id}
            />
          </Label>
          {#if form.notify}
            <Textarea bind:value={form.message} rows={2} placeholder="A note to them (optional)" />
            {#if errors.message}<p class="text-sm text-destructive">Message {errors.message}</p>{/if}
          {/if}
        </div>

        <StreakPreviewPanel preview={shown} {loading} />
        {#if errors.base}<p class="text-sm text-destructive">{errors.base}</p>{/if}
      </div>

      <Dialog.Footer>
        <Button type="button" variant="outline" onclick={() => (open = false)}>Cancel</Button>
        <Button type="submit" disabled={blocked}>{action}</Button>
      </Dialog.Footer>
    </form>
  </Dialog.Content>
</Dialog.Root>
