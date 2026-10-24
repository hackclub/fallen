<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link, router } from '@inertiajs/svelte'
  import Bot from '@lucide/svelte/icons/bot'
  import Check from '@lucide/svelte/icons/check'
  import Copy from '@lucide/svelte/icons/copy'
  import Plus from '@lucide/svelte/icons/plus'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Dialog from '@/components/admin/ui/dialog'
  import { Input } from '@/components/admin/ui/input'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { csrfToken } from '@/lib/csrf'
  import { guessDevice, mcpClients, tokenNamePart } from '@/lib/mcpClients'
  import { formatDate, timeAgo } from '@/lib/format'
  import { adminMcp, adminMcpToken, adminMcpTokens, adminSqlChange } from '@/routes'
  import type { AdminMcpAction, AdminMcpToken, AdminSqlChange } from '@/types'

  let {
    tokens,
    actions,
    sql_changes,
    mcp_url,
    max_lifetime_days,
    default_handle,
  }: {
    tokens: AdminMcpToken[]
    actions?: AdminMcpAction[]
    sql_changes?: AdminSqlChange[]
    mcp_url: string
    max_lifetime_days: number
    default_handle: string
  } = $props()

  let creating = $state(false)
  // A token is named name@device (AdminToken::NAME_FORMAT): who holds it and where it lives.
  let handle = $state('')
  let device = $state('')
  const name = $derived(`${handle}@${device}`)
  const nameTaken = $derived(tokens.some((token) => token.live && token.name === name))
  let client = $state(mcpClients[0].key)
  let days = $state(30)
  let error = $state<string | null>(null)
  let saving = $state(false)
  // The raw token, held only in this dialog. It is never sent again.
  let secret = $state<string | null>(null)
  let copied = $state(false)
  let revoking = $state<AdminMcpToken | null>(null)
  let confirming = $state(false)
  let open = $state<number | null>(null)

  const chosen = $derived(mcpClients.find((option) => option.key === client) ?? mcpClients[0])
  const command = $derived(secret && chosen.snippet(mcp_url, secret))

  async function create(event: SubmitEvent) {
    event.preventDefault()
    saving = true
    error = null
    const response = await fetch(adminMcpTokens().url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
      body: JSON.stringify({ name, lifetime_days: days }),
    })
    const body = await response.json().catch(() => ({}))
    saving = false
    if (!response.ok) {
      error = body.error ?? 'That did not work. Try again.'
      return
    }
    secret = body.secret
    router.reload({ only: ['tokens'] })
  }

  function closeCreate(next: boolean) {
    creating = next
    if (next) {
      handle = tokenNamePart(default_handle)
      device = guessDevice()
      return
    }
    secret = null
    days = 30
    error = null
    copied = false
  }

  async function copy() {
    if (!command) return
    await navigator.clipboard.writeText(command)
    copied = true
    setTimeout(() => (copied = false), 2000)
  }

  function revoke(token: AdminMcpToken) {
    router.delete(adminMcpToken(token.id), { preserveScroll: true, onFinish: () => (confirming = false) })
  }
</script>

<svelte:head><title>MCP · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="text-2xl font-semibold tracking-tight">MCP</h1>
    <p class="text-sm text-muted-foreground">
      Tokens that let an agent use this admin panel as you. Every call is logged below.
    </p>
  </div>
  <Button size="sm" onclick={() => closeCreate(true)}><Plus data-icon="inline-start" /> New token</Button>
</div>

{#if tokens.length === 0}
  <EmptyState
    icon={Bot}
    title="No tokens yet"
    description="Make one to connect Claude Code. It can do what you can do here, except browse as someone or make tokens."
  />
{:else}
  <ul class="mb-8 divide-y divide-border overflow-hidden rounded-md border border-border">
    {#each tokens as token (token.id)}
      <li class="flex items-center gap-4 px-4 py-3">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="truncate text-sm font-medium">{token.name}</span>
            <span class="font-mono text-xs text-muted-foreground">…{token.token_hint}</span>
            {#if token.revoked_at}
              <Badge variant="secondary">Revoked</Badge>
            {:else if !token.live}
              <Badge variant="secondary">Expired</Badge>
            {/if}
          </div>
          <p class="mt-0.5 text-xs text-muted-foreground">
            {token.owner.name} · made {formatDate(token.created_at)} ·
            {token.last_used_at ? `used ${timeAgo(token.last_used_at)}` : 'never used'}
            {#if token.live}· expires {formatDate(token.expires_at)}{/if}
          </p>
        </div>
        {#if token.live}
          <Button
            size="sm"
            variant="outline"
            onclick={() => {
              revoking = token
              confirming = true
            }}>Revoke</Button
          >
        {/if}
      </li>
    {/each}
  </ul>
{/if}

<h2 class="mb-3 text-lg font-semibold">SQL changes</h2>
<Deferred data="sql_changes">
  {#snippet fallback()}<Skeleton class="mb-8 h-20 w-full" />{/snippet}
  {#if !sql_changes?.length}
    <p class="mb-8 text-sm text-muted-foreground">
      Writes an agent asks for with query_sql wait here for approval.
    </p>
  {:else}
    <ul class="mb-8 divide-y divide-border overflow-hidden rounded-md border border-border">
      {#each sql_changes as change (change.id)}
        <li>
          <Link
            href={adminSqlChange(change.id)}
            class="flex items-center gap-3 px-4 py-2.5 text-sm hover:bg-muted/50"
          >
            <Badge variant={change.state === 'pending' ? 'default' : 'secondary'}>{change.state}</Badge>
            <span class="font-mono">{change.kind} {change.table_name}</span>
            <span class="min-w-0 flex-1"></span>
            <span class="text-xs text-muted-foreground"
              >{change.requested_by.name} · {timeAgo(change.created_at)}</span
            >
          </Link>
        </li>
      {/each}
    </ul>
  {/if}
</Deferred>

<h2 class="mb-3 text-lg font-semibold">Recent calls</h2>
<Deferred data="actions">
  {#snippet fallback()}<Skeleton class="h-40 w-full" />{/snippet}
  {#if !actions?.length}
    <p class="text-sm text-muted-foreground">Nothing yet.</p>
  {:else}
    <ul class="divide-y divide-border overflow-hidden rounded-md border border-border">
      {#each actions as action (action.id)}
        <li>
          <button
            type="button"
            class="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm hover:bg-muted/50"
            onclick={() => (open = open === action.id ? null : action.id)}
          >
            <span class="font-mono">{action.tool}</span>
            {#if action.kind === 'write'}<Badge variant="outline">write</Badge>{/if}
            {#if action.status !== 'ok'}<Badge variant="destructive">{action.status}</Badge>{/if}
            <span class="min-w-0 flex-1 truncate text-xs text-muted-foreground">{action.subject ?? ''}</span>
            <span class="text-xs text-muted-foreground"
              >{action.admin.name} · {timeAgo(action.created_at)}</span
            >
          </button>
          {#if open === action.id}
            <div class="space-y-2 bg-muted/30 px-4 py-3 text-xs">
              {#if action.error}<p class="text-destructive">{action.error}</p>{/if}
              <pre class="overflow-x-auto font-mono whitespace-pre-wrap">{JSON.stringify(
                  action.arguments,
                  null,
                  2,
                )}</pre>
              <p class="text-muted-foreground">#{action.id} · {action.duration_ms ?? '?'} ms</p>
            </div>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</Deferred>

<AlertDialog.Root bind:open={confirming}>
  <AlertDialog.Content>
    {#if revoking}
      <AlertDialog.Header>
        <AlertDialog.Title>Revoke {revoking.name}?</AlertDialog.Title>
        <AlertDialog.Description>
          It stops working at once. Its calls stay in the log.
        </AlertDialog.Description>
      </AlertDialog.Header>
      <AlertDialog.Footer>
        <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
        <AlertDialog.Action variant="destructive" onclick={() => revoking && revoke(revoking)}
          >Revoke</AlertDialog.Action
        >
      </AlertDialog.Footer>
    {/if}
  </AlertDialog.Content>
</AlertDialog.Root>

<Dialog.Root bind:open={() => creating, closeCreate}>
  <Dialog.Content class="sm:max-w-lg">
    {#if secret}
      <Dialog.Header>
        <Dialog.Title>Your token</Dialog.Title>
        <Dialog.Description>
          This is the only time it is shown. Pick where you use it and add it there now.
        </Dialog.Description>
      </Dialog.Header>
      <ToggleGroup.Root
        type="single"
        variant="outline"
        size="sm"
        value={client}
        onValueChange={(value) => value && ((client = value), (copied = false))}
        class="flex-wrap"
      >
        {#each mcpClients as option (option.key)}
          <ToggleGroup.Item value={option.key} class="px-3">{option.label}</ToggleGroup.Item>
        {/each}
      </ToggleGroup.Root>
      <p class="text-sm text-muted-foreground">{chosen.where}</p>
      <pre
        class="max-h-64 overflow-auto rounded-md bg-muted p-3 font-mono text-xs break-all whitespace-pre-wrap">{command}</pre>
      <Dialog.Footer>
        <Button variant="outline" onclick={copy}>
          {#if copied}<Check data-icon="inline-start" /> Copied{:else}<Copy data-icon="inline-start" /> Copy{/if}
        </Button>
        <Button onclick={() => closeCreate(false)}>Done</Button>
      </Dialog.Footer>
    {:else}
      <form onsubmit={create} class="contents">
        <Dialog.Header>
          <Dialog.Title>New token</Dialog.Title>
          <Dialog.Description>
            It acts as you. Anyone holding it can do what you can do in this panel until it expires or is
            revoked.
          </Dialog.Description>
        </Dialog.Header>
        <div class="space-y-2">
          <Label for="token-device">Name</Label>
          <!-- Two fields read as one, name@device, with the name half ending at the @. -->
          <div
            class="flex h-9 items-center rounded-md border border-input font-mono text-sm shadow-xs transition-[color,box-shadow] focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50 dark:bg-input/30"
          >
            <input
              aria-label="Your name"
              bind:value={() => handle, (value) => (handle = tokenNamePart(value))}
              placeholder="you"
              autocomplete="off"
              spellcheck={false}
              class="h-full w-0 flex-1 border-0 bg-transparent py-0 pr-0 pl-3 text-right font-mono text-sm shadow-none outline-none placeholder:text-muted-foreground focus:ring-0"
            />
            <span class="px-0.5 text-muted-foreground">@</span>
            <!-- svelte-ignore a11y_autofocus -->
            <input
              id="token-device"
              aria-label="Device"
              bind:value={() => device, (value) => (device = tokenNamePart(value))}
              placeholder="laptop"
              autocomplete="off"
              spellcheck={false}
              autofocus
              class="h-full w-0 flex-1 border-0 bg-transparent py-0 pr-3 pl-0 font-mono text-sm shadow-none outline-none placeholder:text-muted-foreground focus:ring-0"
            />
          </div>
          {#if nameTaken}
            <p class="text-xs text-amber-600 dark:text-amber-400">
              You already have a live token called {name}. Revoke it if this one replaces it.
            </p>
          {:else}
            <p class="text-xs text-muted-foreground">
              Who holds it and where it lives, like <span class="font-mono">{default_handle}@work-laptop</span
              >.
            </p>
          {/if}
        </div>
        <div class="space-y-2">
          <Label for="token-days">Lasts for (days)</Label>
          <Input id="token-days" type="number" bind:value={days} min={1} max={max_lifetime_days} />
        </div>
        {#if error}<p class="text-sm text-destructive">{error}</p>{/if}
        <Dialog.Footer>
          <Button type="button" variant="outline" onclick={() => closeCreate(false)}>Cancel</Button>
          <Button type="submit" disabled={!handle || !device || saving}>Make token</Button>
        </Dialog.Footer>
      </form>
    {/if}
  </Dialog.Content>
</Dialog.Root>
