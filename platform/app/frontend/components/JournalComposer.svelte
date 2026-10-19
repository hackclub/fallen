<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import LapsePicker, { type LapseStatus } from '@/components/LapsePicker.svelte'
  import MarkdownEditor from '@/components/MarkdownEditor.svelte'
  import Sketchbook from '@/components/Sketchbook.svelte'
  import { formatDate } from '@/lib/format'
  import { MINUTES_PER_PHOTO, MIN_JOURNAL_LENGTH, countWords, writtenLength } from '@/lib/markdown'
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

  // Photos live in the writing; deleting one there drops it. Photos a Slack journal brought along aren't in its
  // writing, so they stay.
  // svelte-ignore state_referenced_locally
  const unembedded = new Set(
    (journal?.images ?? []).filter((i) => !journal?.body.includes(i.id)).map((i) => i.id),
  )
  const photos = $derived(form.images.filter((i) => unembedded.has(i.id) || form.body.includes(i.id)))
  const hours = $derived(form.duration.trim().match(/^(\d*\.?\d+)\s*h?$/i)?.[1])
  const photosNeeded = $derived(hours ? Math.ceil((parseFloat(hours) * 60) / MINUTES_PER_PHOTO) : null)

  function addImage(image: UploadedImage) {
    uploadError = null
    form.images = [...form.images, image]
  }

  function submit(event: SubmitEvent) {
    event.preventDefault()
    if (!canSubmit) return
    const target = editing && journal ? journals.update(journal.id) : projectJournals(project.id)
    form
      .transform((data) => ({ journal: { ...data, images: photos.map((i) => i.id) } }))
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
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
      <section
        class="flex min-h-[340px] cursor-text flex-col gap-2 lg:min-h-0"
        onclick={(e) => {
          if (!(e.target as Element).closest('button, input, a, .ProseMirror')) editor?.focus()
        }}
      >
        <h3 id="journal-body-label" class="font-display text-xl text-ink">What did you do?</h3>
        <MarkdownEditor
          labelledby="journal-body-label"
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
            {:else if form.errors.images}<span class="text-red-700">{form.errors.images}</span>
            {:else if uploadError}<span class="text-red-700">{uploadError}</span>
            {:else if draftRestored}Draft restored.{/if}
          </span>
          <span class="flex shrink-0 gap-3 tabular-nums">
            <span>
              {#if photosNeeded !== null}{photos.length}/{photosNeeded}
                {photosNeeded === 1 ? 'photo' : 'photos'}
              {:else}{photos.length} {photos.length === 1 ? 'photo' : 'photos'}{/if}
            </span>
            <span>
              {#if longEnough}{words} {words === 1 ? 'word' : 'words'}{:else}{written}/{MIN_JOURNAL_LENGTH} characters{/if}
            </span>
          </span>
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
            {#if form.errors.duration || fromTracking || timelapsed}
              <p id="duration-help" class="mt-1 font-outfit text-xs text-ink-soft">
                {#if form.errors.duration}<span class="text-red-700">{form.errors.duration}</span>
                {:else if fromTracking}Filled in from the time you tracked.
                {:else}Leave it empty to use your timelapses' time.{/if}
              </p>
            {/if}
          </div>
        </div>

        <!-- Room for the button's press-down edge and focus ring, which the scrolling grid would clip. -->
        <div class="mt-4 border-t-2 border-dashed border-paper-edge/70 px-1.5 pt-4 pb-2">
          <button type="submit" class="sketch-button w-full" disabled={!canSubmit}>
            {form.processing ? 'Logging…' : editing ? 'Save journal' : 'Log journal'}
          </button>
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
