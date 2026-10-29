<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link, router, useForm } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import Ban from '@lucide/svelte/icons/ban'
  import VenetianMask from '@lucide/svelte/icons/venetian-mask'
  import DataTable from '@/components/admin/DataTable.svelte'
  import RoleBadges from '@/components/admin/RoleBadges.svelte'
  import StreakCard from '@/components/admin/streaks/StreakCard.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { projectColumns, trialLabel } from '@/lib/adminColumns'
  import { formatDate, formatDateTime } from '@/lib/format'
  import { adminUsers, impersonateAdminUser } from '@/routes'
  import type { AdminProject, AdminStreak, AdminTimezoneChange, AdminUserDetail } from '@/types'

  let {
    user,
    projects,
    roles,
    can,
    streak,
    streak_blocked,
    timezone_changes,
  }: {
    user: AdminUserDetail
    projects: AdminProject[]
    roles: string[]
    can: { update: boolean; impersonate: boolean; streak: boolean }
    streak?: AdminStreak
    streak_blocked: string | null
    timezone_changes?: AdminTimezoneChange[]
  } = $props()

  // svelte-ignore state_referenced_locally
  const rolesForm = useForm({ roles: [...user.roles] })
  // svelte-ignore state_referenced_locally
  const banForm = useForm({ is_banned: !user.is_banned })

  let confirmRoles = $state(false)
  let confirmBan = $state(false)

  const rolesChanged = $derived(
    rolesForm.roles.length !== user.roles.length ||
      rolesForm.roles.some((role) => !user.roles.includes(role)),
  )
  const columns = projectColumns({ owner: false })

  const details = $derived([
    { label: 'Public ID', value: user.id, mono: true },
    { label: 'HCA ID', value: user.hca_id ?? '—', mono: true },
    { label: 'Slack ID', value: user.slack_id ?? '—', mono: true },
    { label: 'Timezone', value: user.timezone },
    { label: 'Verification', value: user.verification_status ?? 'unknown' },
    { label: 'Adult', value: user.is_adult ? 'Yes' : 'No' },
    {
      label: 'XP',
      value: `${user.xp} (stage ${Math.max(user.pet_form, 1)}${user.pet ? `, ${user.pet}` : ''})`,
    },
    { label: 'Last seen', value: formatDateTime(user.last_seen_at) },
    { label: 'Joined', value: formatDate(user.created_at) },
    { label: 'Came from', value: signupSource(user.signup_source) },
  ])

  function signupSource(source: Record<string, string>) {
    const tags = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'ref']
      .filter((key) => source[key])
      .map((key) => `${key.replace('utm_', '')}=${source[key]}`)
    return [...tags, source.referrer].filter(Boolean).join(', ') || '—'
  }

  function toggleRole(role: string, checked: boolean) {
    rolesForm.roles = checked ? [...rolesForm.roles, role] : rolesForm.roles.filter((r) => r !== role)
  }

  function saveRoles() {
    rolesForm
      .transform((data) => ({ user: data }))
      .submit(adminUsers.update(user.id), {
        preserveScroll: true,
        onFinish: () => (confirmRoles = false),
      })
  }

  function saveBan() {
    banForm.is_banned = !user.is_banned
    banForm
      .transform((data) => ({ user: data }))
      .submit(adminUsers.update(user.id), {
        preserveScroll: true,
        onFinish: () => (confirmBan = false),
      })
  }
</script>

<svelte:head><title>{user.display_name} · Fallen Admin</title></svelte:head>

<Link
  href={adminUsers.index()}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" /> Users
</Link>

<div class="flex flex-wrap items-center gap-4">
  <img src={user.avatar} alt="" class="size-14 rounded-full bg-muted object-cover" />
  <div class="min-w-0">
    <div class="flex items-center gap-2">
      <h1 class="text-2xl font-semibold tracking-tight">{user.display_name}</h1>
      {#if user.is_trial}<Badge variant="secondary">{trialLabel(user)}</Badge>{/if}
      {#if user.is_banned}<Badge variant="destructive">Banned</Badge>{/if}
      {#if user.discarded_at}<Badge variant="destructive">Deleted</Badge>{/if}
    </div>
    <p class="text-sm text-muted-foreground">{user.email}</p>
  </div>
  <div class="ml-auto flex items-center gap-2">
    <RoleBadges roles={user.roles} />
    {#if can.impersonate}
      <Button variant="outline" size="sm" onclick={() => router.visit(impersonateAdminUser(user.id))}>
        <VenetianMask data-icon="inline-start" /> Impersonate
      </Button>
    {/if}
  </div>
</div>

<div class="mt-6 grid gap-4 lg:grid-cols-3">
  <Card.Root class="lg:col-span-2">
    <Card.Header><Card.Title>Details</Card.Title></Card.Header>
    <Card.Content>
      <dl class="grid grid-cols-2 gap-x-6 gap-y-4 text-sm sm:grid-cols-4">
        {#each details as detail (detail.label)}
          <div class="min-w-0">
            <dt class="text-muted-foreground">{detail.label}</dt>
            <dd class={['truncate', detail.mono && 'font-mono text-xs leading-5']}>{detail.value}</dd>
          </div>
        {/each}
      </dl>
    </Card.Content>
  </Card.Root>

  <Card.Root>
    <Card.Header>
      <Card.Title>Access</Card.Title>
      <Card.Description>
        {can.update ? 'Roles and bans apply on the next request.' : "You can't edit your own account."}
      </Card.Description>
    </Card.Header>
    <Card.Content class="space-y-4">
      <div class="flex flex-wrap gap-4">
        {#each roles as role (role)}
          <Label class="flex items-center gap-2 font-normal">
            <Checkbox
              checked={rolesForm.roles.includes(role)}
              onCheckedChange={(checked) => toggleRole(role, checked)}
              disabled={!can.update}
            />
            {role}
          </Label>
        {/each}
      </div>
      {#if rolesForm.errors.roles}<p class="text-sm text-destructive">{rolesForm.errors.roles}</p>{/if}

      <div class="flex flex-wrap gap-2">
        <AlertDialog.Root bind:open={confirmRoles}>
          <AlertDialog.Trigger>
            {#snippet child({ props })}
              <Button {...props} size="sm" disabled={!can.update || !rolesChanged}>Save roles</Button>
            {/snippet}
          </AlertDialog.Trigger>
          <AlertDialog.Content>
            <AlertDialog.Header>
              <AlertDialog.Title>Update roles for {user.display_name}?</AlertDialog.Title>
              <AlertDialog.Description>
                They will have: {rolesForm.roles.join(', ') || 'no roles'}.
              </AlertDialog.Description>
            </AlertDialog.Header>
            <AlertDialog.Footer>
              <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
              <AlertDialog.Action onclick={saveRoles} disabled={rolesForm.processing}
                >Update roles</AlertDialog.Action
              >
            </AlertDialog.Footer>
          </AlertDialog.Content>
        </AlertDialog.Root>

        <AlertDialog.Root bind:open={confirmBan}>
          <AlertDialog.Trigger>
            {#snippet child({ props })}
              <Button
                {...props}
                size="sm"
                variant={user.is_banned ? 'outline' : 'destructive'}
                disabled={!can.update}
              >
                <Ban data-icon="inline-start" />
                {user.is_banned ? 'Unban' : 'Ban'}
              </Button>
            {/snippet}
          </AlertDialog.Trigger>
          <AlertDialog.Content>
            <AlertDialog.Header>
              <AlertDialog.Title>{user.is_banned ? 'Unban' : 'Ban'} {user.display_name}?</AlertDialog.Title>
              <AlertDialog.Description>
                {user.is_banned
                  ? 'They will be able to sign in and use Fallen again.'
                  : 'Every page will send them to /sorry until they are unbanned.'}
              </AlertDialog.Description>
            </AlertDialog.Header>
            <AlertDialog.Footer>
              <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
              <AlertDialog.Action
                variant={user.is_banned ? 'default' : 'destructive'}
                onclick={saveBan}
                disabled={banForm.processing}
              >
                {user.is_banned ? 'Unban' : 'Ban'}
              </AlertDialog.Action>
            </AlertDialog.Footer>
          </AlertDialog.Content>
        </AlertDialog.Root>
      </div>
    </Card.Content>
  </Card.Root>
</div>

<Deferred data="streak">
  {#snippet fallback()}
    <Skeleton class="mt-6 h-72 w-full rounded-xl" />
  {/snippet}
  {#if streak}<StreakCard {user} {streak} canAdjust={can.streak} blocked={streak_blocked} />{/if}
</Deferred>

<!-- The day a journal counts for follows the timezone, so changes are limited and kept (User#change_timezone). -->
<Deferred data="timezone_changes">
  {#snippet fallback()}{/snippet}
  {#if timezone_changes?.length}
    <Card.Root class="mt-6">
      <Card.Header>
        <Card.Title>Timezone changes</Card.Title>
        <Card.Description
          >The latest first. A refused change came too soon after the last one.</Card.Description
        >
      </Card.Header>
      <Card.Content>
        <ul class="space-y-2 text-sm">
          {#each timezone_changes as change (change.created_at + change.to)}
            <li class="flex flex-wrap items-center gap-2">
              <span class="text-muted-foreground tabular-nums">{formatDateTime(change.created_at)}</span>
              <span>{change.from} → {change.to}</span>
              {#if change.refused}<Badge variant="destructive" class="text-[10px]">Refused</Badge>{/if}
            </li>
          {/each}
        </ul>
      </Card.Content>
    </Card.Root>
  {/if}
</Deferred>

<h2 class="mt-8 mb-4 text-lg font-semibold tracking-tight">{user.display_name}'s projects</h2>
<DataTable {columns} data={projects} noun="projects" />
