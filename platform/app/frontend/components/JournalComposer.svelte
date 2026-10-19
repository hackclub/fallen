<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import LapsePicker, { type LapseStatus } from '@/components/LapsePicker.svelte'
  import MarkdownEditor from '@/components/MarkdownEditor.svelte'
  import Sketchbook from '@/components/Sketchbook.svelte'
  import { formatDate } from '@/lib/format'
  import { MIN_JOURNAL_LENGTH, countWords, writtenLength } from '@/lib/markdown'
  import { trackedHours } from '@/lib/timer.svelte'
  import type { UploadedImage } from '@/lib/uploads'
  import { journals, project as projectRoute, projectJournals } from '@/routes'
  import type { Journal, Project } from '@/types'

  let {
    project,
    journal = null,
    directUploadUrl,
    lapse,
    onClose,
  }: {
    project: Project
    journal?: Journal | null
    directUploadUrl: string
    lapse?: LapseStatus | null
    onClose: () => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const draftKey = `fallen:journal-draft:${project.id}`
  // svelte-ignore state_referenced_locally
  const editing = journal !== null

  // svelte-ignore state_referenced_locally
  const form = useForm({
    body: journal?.body ?? '',
    duration: journal?.duration_text?.replace(/h$/, '') ?? '',
    lapse_timelapses: (journal?.lapse_timelapses ?? []).map((t) => t.id),
    images: (journal?.images ?? []) as UploadedImage[],
  })

  let editor: MarkdownEditor | undefined = $state()
  let uploadError: string | null = $state(null)
  let draftRestored = $state(false)
  // The hours the huddle and site timer tracked since the last journal, put in the box for a new journal. The note
  // saying so stays while the box still holds exactly that. The server decides what counts as self-claimed.
  let prefilled = $state('')
  const fromTracking = $derived(prefilled !== '' && form.duration.trim() === prefilled)

  onMount(() => {
    if (editing) return
    trackedHours().then((hours) => {
      if (hours && form.duration.trim() === '') form.duration = prefilled = hours
    })
    try {
      const draft = localStorage.getItem(draftKey)
      if (draft) {
        const parsed = JSON.parse(draft)
        form.body = parsed.body ?? ''
        form.duration = parsed.duration ?? ''
        form.lapse_timelapses = parsed.lapse_timelapses ?? []
        form.images = parsed.images ?? []
        draftRestored = true
      }
    } catch {
      /* no draft */
    }
  })

  $effect(() => {
    if (editing) return
    const snapshot = {
      body: form.body,
      duration: form.duration,
      lapse_timelapses: form.lapse_timelapses,
      images: form.images,
    }
    const timer = setTimeout(() => {
      try {
        if (snapshot.body || snapshot.images.length) localStorage.setItem(draftKey, JSON.stringify(snapshot))
        else localStorage.removeItem(draftKey)
      } catch {
        /* storage unavailable */
      }
    }, 400)
    return () => clearTimeout(timer)
  })

  const words = $derived(countWords(form.body))
  const written = $derived(writtenLength(form.body))
  // Enough for a reviewer to follow. An older, shorter journal can still be saved as long as its text is untouched.
  const longEnough = $derived(written >= MIN_JOURNAL_LENGTH || (editing && form.body === journal?.body))
  // Typed hours always count. With timelapses picked and nothing typed, the server takes their recorded time.
  const timelapsed = $derived(form.lapse_timelapses.length > 0)
  const canSubmit = $derived(
    form.body.trim().length > 0 &&
      longEnough &&
      (timelapsed || form.duration.trim().length > 0) &&
      !form.processing,
  )

  function addImage(image: UploadedImage) {
    uploadError = null
    form.images = [...form.images, image]
  }

  function removeImage(image: UploadedImage) {
    form.images = form.images.filter((i) => i.id !== image.id)
    form.body = form.body.replace(
      new RegExp(`!\\[[^\\]]*\\]\\(${image.url.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\)\\n?`, 'g'),
      '',
    )
  }

  function submit(event: SubmitEvent) {
    event.preventDefault()
    if (!canSubmit) return
    const target = editing && journal ? journals.update(journal.id) : projectJournals(project.id)
    form
      .transform((data) => ({ journal: { ...data, images: data.images.map((i) => i.id) } }))
      .submit(target, {
        preserveScroll: true,
        onSuccess: () => {
          try {
            localStorage.removeItem(draftKey)
          } catch {
            /* ignore */
          }
          onClose()
        },
      })
  }

  function onKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') onClose()
  }
</script>

<svelte:window onkeydown={onKeydown} />

<Sketchbook titleId="composer-title" {onClose}>
  <form onsubmit={submit} class="flex min-h-0 flex-1 flex-col">
    <header
      class="mr-12 flex items-end justify-between gap-4 border-b-2 border-dashed border-paper-edge/70 pb-3"
    >
      <div class="min-w-0">
        <p class="font-outfit text-[11px] font-bold tracking-[0.18em] text-ink-soft uppercase">
          {editing ? 'Editing a journal for' : 'Journaling for'}
        </p>
        <h2 id="composer-title" class="truncate font-display text-3xl leading-tight text-ink">
          {project.title}
        </h2>
      </div>
      <p class="shrink-0 pb-1 font-display text-lg text-ink-soft">
        {formatDate(journal?.created_at ?? new Date().toISOString())}
      </p>
    </header>

    <div
      class="grid min-h-0 flex-1 gap-x-7 overflow-y-auto pt-4 lg:grid-cols-[minmax(0,1fr)_minmax(290px,38%)] lg:overflow-hidden"
    >
      <section class="flex min-h-[340px] flex-col gap-2 lg:min-h-0">
        <label for="journal-body" class="font-display text-xl text-ink">What did you do?</label>
        <MarkdownEditor
          id="journal-body"
          bind:this={editor}
          bind:value={form.body}
          {directUploadUrl}
          onUpload={addImage}
          onError={(message) => (uploadError = message)}
          placeholder="What you built, what broke, what you figured out. Drop or paste photos anywhere in here."
        />
        <div class="flex items-center justify-between gap-3 font-outfit text-xs text-ink-soft">
          <span>
            {#if form.errors.body}<span class="text-red-700">{form.errors.body}</span>
            {:else if uploadError}<span class="text-red-700">{uploadError}</span>
            {:else if !longEnough && written > 0}Write at least {MIN_JOURNAL_LENGTH} characters so a reviewer can
              follow what you did.
            {:else if draftRestored}Draft restored.{/if}
          </span>
          <span class="shrink-0 tabular-nums">
            {#if longEnough}{words} {words === 1 ? 'word' : 'words'}{:else}{written}/{MIN_JOURNAL_LENGTH} characters{/if}
          </span>
        </div>
        <div class="mt-2 flex items-center gap-3">
          <ul class="sketch-scroll flex min-w-0 gap-2 overflow-x-auto p-0.5" aria-label="Photos">
            <li class="shrink-0">
              <button
                type="button"
                onclick={() => editor?.pickFiles()}
                class="flex size-14 cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-paper-edge font-outfit text-[11px] leading-tight text-ink-soft transition-colors hover:border-[var(--sb-ring)] hover:text-[var(--sb-ring-deep)]"
              >
                <span class="text-lg leading-none">+</span>
                photo
              </button>
            </li>
            {#each form.images as image (image.id)}
              <li
                class="group relative size-14 shrink-0 overflow-hidden rounded-lg border-2 border-paper-edge"
              >
                <img src={image.url} alt={image.filename} class="h-full w-full object-cover" />
                <button
                  type="button"
                  aria-label="Remove {image.filename}"
                  onclick={() => removeImage(image)}
                  class="absolute top-0.5 right-0.5 flex size-5 items-center justify-center rounded-full bg-ink/80 text-xs text-paper opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100"
                >
                  ×
                </button>
              </li>
            {/each}
          </ul>
          <p class="min-w-32 shrink-0 font-outfit text-xs text-ink-soft">
            {#if form.errors.images}<span class="text-red-700">{form.errors.images}</span>
            {:else}One photo for every 2 hours logged.{/if}
          </p>
        </div>
      </section>

      <aside class="mt-6 flex flex-col lg:mt-0 lg:min-h-0">
        <div class="flex flex-1 flex-col gap-5 lg:min-h-0">
          <LapsePicker
            {lapse}
            current={journal?.lapse_timelapses}
            bind:selected={form.lapse_timelapses}
            returnTo={`${projectRoute(project.id).url}#write`}
            error={form.errors.lapse_timelapses}
          />

          <div class="shrink-0">
            <div class="flex items-center justify-between gap-3">
              <label for="journal-duration" class="font-display text-xl text-ink">Hours</label>
              <span class="flex items-baseline gap-1.5">
                <input
                  id="journal-duration"
                  type="text"
                  bind:value={form.duration}
                  placeholder={timelapsed ? 'auto' : '1.5'}
                  inputmode="decimal"
                  required={!timelapsed}
                  aria-describedby="duration-help"
                  class="hours-input"
                />
                <span class="font-outfit text-sm text-ink-soft">h</span>
              </span>
            </div>
            <p id="duration-help" class="mt-1 font-outfit text-xs text-ink-soft">
              {#if form.errors.duration}<span class="text-red-700">{form.errors.duration}</span>
              {:else if fromTracking}Filled in from the time you tracked.
              {:else if timelapsed}Leave it empty to use your timelapses' time.
              {:else}Every journal needs some: 1.5, 0.5, 0.1.{/if}
              A thin journal can get its hours deflated.
            </p>
          </div>
        </div>

        <div class="mt-4 border-t-2 border-dashed border-paper-edge/70 pt-4">
          <button type="submit" class="sketch-button w-full" disabled={!canSubmit}>
            {form.processing ? 'Logging…' : editing ? 'Save journal' : 'Log journal'}
          </button>
          <p class="mt-2 text-center font-outfit text-xs text-ink-soft">
            Posts to your project thread in Slack as you.
          </p>
        </div>
      </aside>
    </div>
  </form>
</Sketchbook>

<style>
  .hours-input {
    width: 4.5rem;
    border: 0;
    border-bottom: 2px solid var(--color-paper-edge);
    background: transparent;
    padding: 0 0.25rem;
    color: var(--color-ink);
    font-family: var(--font-display);
    font-size: 1.6rem;
    line-height: 1.2;
    text-align: right;
  }
  .hours-input::placeholder {
    color: color-mix(in srgb, var(--color-ink-soft) 45%, transparent);
  }
  .hours-input:focus {
    border-color: var(--sb-ring);
    outline: none;
    box-shadow: none;
  }
</style>
