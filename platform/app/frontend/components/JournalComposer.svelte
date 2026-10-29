<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { onDestroy, onMount, untrack } from 'svelte'
  import HoursCheckDialog from '@/components/HoursCheckDialog.svelte'
  import LapsePicker, { type LapseStatus } from '@/components/LapsePicker.svelte'
  import MarkdownEditor from '@/components/MarkdownEditor.svelte'
  import Sketchbook from '@/components/Sketchbook.svelte'
  import SubmitButton from '@/components/SubmitButton.svelte'
  import WritingCheckDialog from '@/components/WritingCheckDialog.svelte'
  import { formatDate } from '@/lib/format'
  import {
    HOURS_REMINDER_MINUTES,
    MAX_PHOTOS,
    MINUTES_PER_PHOTO,
    countWords,
    journalLengthNeeded,
    writtenLength,
  } from '@/lib/markdown'
  import { trackedHours } from '@/lib/timer.svelte'
  import type { UploadedImage } from '@/lib/uploads'
  import { checkWriting, type WritingCheckMode } from '@/lib/writingCheck'
  import { journals, project as projectRoute, projectJournals } from '@/routes'
  import type { Journal, Project } from '@/types'

  let {
    project,
    journal = null,
    directUploadUrl,
    lapse,
    writingCheck = null,
    onClose,
  }: {
    project: Project
    journal?: Journal | null
    directUploadUrl: string
    lapse?: LapseStatus | null
    // Ask Pangram about new writing before posting it, or only remind people who pasted text in (WritingCheckDialog).
    writingCheck?: WritingCheckMode | null
    onClose: () => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const draftKey = `fallen:journal-draft:${project.id}`
  // svelte-ignore state_referenced_locally
  const editing = journal !== null
  // Hours and the timelapses behind them can't change once logged (Journal#hours_unchanged); the writing can.
  // svelte-ignore state_referenced_locally
  const locked = editing && journal?.duration_minutes != null

  // svelte-ignore state_referenced_locally
  const form = useForm({
    body: journal?.body ?? '',
    duration: journal?.duration_text?.replace(/h$/, '') ?? '',
    lapse_timelapses: (journal?.lapse_timelapses ?? []).map((t) => t.id),
    images: (journal?.images ?? []) as UploadedImage[],
  })

  let editor: MarkdownEditor | undefined = $state()
  let uploadError: string | null = $state(null)
  let uploading = $state(0)
  let draftRestored = $state(false)
  // While Pangram reads the writing the button looks the same as while posting. A flagged check, or pasted text
  // without Pangram, waits on the dialog.
  let checking = $state(false)
  let reminder: { checkId?: string } | null = $state(null)
  let pasted = $state(false)
  let hoursCheck = $state(false)
  let durationInput: HTMLInputElement | undefined = $state()
  let pasteHint: HTMLParagraphElement | undefined = $state()
  let selfWritten = $state(false)
  const closing = new AbortController()
  onDestroy(() => closing.abort())
  // A new journal's box offers whichever is more: the hours the huddle and site timer tracked since the last journal,
  // or the picked timelapses' recorded time. It follows the picks until the person types something else. The server
  // decides what counts as self-claimed.
  let tracked = $state(0)
  const picked = $derived(
    (lapse?.timelapses ?? [])
      .filter((t) => form.lapse_timelapses.includes(t.id))
      .reduce((sum, t) => sum + t.duration_minutes, 0),
  )
  const offered = $derived(Math.max(tracked, Math.round((picked / 60) * 100) / 100))
  let prefilled = $state('')
  const autoFilled = $derived(prefilled !== '' && form.duration.trim() === prefilled)

  $effect(() => {
    if (editing) return
    const next = offered > 0 ? String(offered) : ''
    untrack(() => {
      if (form.duration.trim() === prefilled) form.duration = prefilled = next
    })
  })

  onMount(() => {
    if (editing) return
    trackedHours().then((hours) => (tracked = parseFloat(hours) || 0))
    try {
      const draft = localStorage.getItem(draftKey)
      if (draft) {
        const parsed = JSON.parse(draft)
        form.body = parsed.body ?? ''
        form.duration = parsed.duration ?? ''
        form.lapse_timelapses = parsed.lapse_timelapses ?? []
        form.images = parsed.images ?? []
        pasted = parsed.pasted ?? false
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
      pasted,
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
  const timelapsed = $derived(form.lapse_timelapses.length > 0)
  const hours = $derived(form.duration.trim().match(/^(\d*\.?\d+)\s*h?$/i)?.[1])
  // What the server will log: typed hours, or the picked timelapses' time when nothing is typed.
  const minutes = $derived(
    locked ? (journal?.duration_minutes ?? 0) : hours ? parseFloat(hours) * 60 : timelapsed ? picked : 0,
  )
  // Enough for a reviewer to follow, more for more hours. An older, shorter journal can still be saved as long as its
  // text is untouched.
  const untouched = $derived(editing && form.body === journal?.body)
  const lengthNeeded = $derived(journalLengthNeeded(minutes))
  const longEnough = $derived(written >= lengthNeeded || untouched)
  // Photos live in the writing; deleting one there drops it. Photos a Slack journal brought along aren't in its
  // writing, so they stay.
  // svelte-ignore state_referenced_locally
  const unembedded = new Set(
    (journal?.images ?? []).filter((i) => !journal?.body.includes(i.id)).map((i) => i.id),
  )
  const photos = $derived(form.images.filter((i) => unembedded.has(i.id) || form.body.includes(i.id)))
  // One per two hours (Journal#images_cover_hours). A journal whose hours are logged may keep the photos it has.
  const photosNeeded = $derived.by(() => {
    if (minutes <= 0) return null
    const needed = Math.ceil(Math.round(minutes) / MINUTES_PER_PHOTO)
    return (locked ? Math.min(needed, journal?.images.length ?? 0) : needed) || null
  })
  const photosMissing = $derived(photosNeeded === null ? 0 : Math.max(photosNeeded - photos.length, 0))
  // Why the button is greyed out, shown on hover. Typed hours always count. With timelapses picked and nothing typed,
  // the server takes their recorded time.
  const blocker = $derived(
    form.body.trim().length === 0
      ? 'Write what you did first.'
      : !longEnough
        ? `Write at least ${lengthNeeded} characters for this many hours (${written} so far).`
        : !selfWritten && !untouched
          ? 'Tick the box saying you wrote it yourself.'
          : !timelapsed && form.duration.trim().length === 0
            ? 'Pick a timelapse or fill in your hours.'
            : uploading > 0
              ? 'Waiting for your photos to upload.'
              : photosMissing > 0
                ? `Add ${photosMissing} more ${photosMissing === 1 ? 'photo' : 'photos'}, one for every ${MINUTES_PER_PHOTO / 60} hours logged.`
                : photos.length > MAX_PHOTOS
                  ? `A journal can hold at most ${MAX_PHOTOS} photos (${photos.length} so far).`
                  : null,
  )
  const canSubmit = $derived(blocker === null && !form.processing && !checking)
  const hoursText = $derived(String(Math.round((minutes / 60) * 100) / 100))

  function addImage(image: UploadedImage) {
    uploadError = null
    form.images = [...form.images, image]
  }

  function submit(event: SubmitEvent) {
    event.preventDefault()
    if (!canSubmit) return
    if (!locked && minutes > HOURS_REMINDER_MINUTES) hoursCheck = true
    else checkThenPost()
  }

  async function checkThenPost() {
    if (!writingCheck || (editing && form.body === journal?.body)) return post()
    if (writingCheck === 'paste') {
      if (pasted) reminder = {}
      else post()
      return
    }

    checking = true
    const check = await checkWriting(form.body, closing.signal)
    checking = false
    if (closing.signal.aborted) return
    if (check?.flagged) reminder = { checkId: check.id }
    else post(check?.id)
  }

  function post(checkId?: string, insisted = false) {
    const target = editing && journal ? journals.update(journal.id) : projectJournals(project.id)
    form
      .transform(({ duration, lapse_timelapses, ...data }) => ({
        journal: {
          ...data,
          ...(locked ? {} : { duration, lapse_timelapses }),
          images: photos.map((i) => i.id),
        },
        ...(checkId ? { writing_check: checkId, insisted } : {}),
      }))
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

  function editFlagged() {
    reminder = null
    editor?.focus()
  }

  function editHours() {
    hoursCheck = false
    durationInput?.focus()
  }

  // Pasted text is a nudge to write it yourself. Pasted photos are welcome, so they don't set it off.
  function onPaste(event: ClipboardEvent) {
    const data = event.clipboardData
    if (!pasteHint || !data || data.files.length > 0 || !data.getData('text/plain').trim()) return
    pasted = true
    pasteHint.classList.remove('flash')
    void pasteHint.offsetWidth
    pasteHint.classList.add('flash')
  }

  function onKeydown(event: KeyboardEvent) {
    if (event.key !== 'Escape') return
    if (hoursCheck) editHours()
    else if (reminder) editFlagged()
    else onClose()
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
        onpaste={onPaste}
      >
        <div class="flex items-end justify-between gap-3">
          <h3 id="journal-body-label" class="font-display text-xl text-ink">What did you do?</h3>
          <p
            bind:this={pasteHint}
            class="paste-hint pb-1 text-right font-outfit text-xs"
            onanimationend={() => pasteHint?.classList.remove('flash')}
          >
            Please write this yourself, humans read it!
          </p>
        </div>
        <MarkdownEditor
          labelledby="journal-body-label"
          bind:this={editor}
          bind:value={form.body}
          bind:uploading
          {directUploadUrl}
          onUpload={addImage}
          onError={(message) => (uploadError = message)}
          placeholder="What you built, what broke, what you figured out. Drop or paste photos anywhere in here."
        >
          {#snippet footer()}
            <span class="min-w-0 truncate">
              {#if form.errors.body}<span class="text-red-700">{form.errors.body}</span>
              {:else if form.errors.images}<span class="text-red-700">{form.errors.images}</span>
              {:else if uploadError}<span class="text-red-700">{uploadError}</span>
              {:else if draftRestored}Draft restored.{/if}
            </span>
            <span class="flex shrink-0 gap-3 tabular-nums">
              <span class:text-red-700={photosMissing > 0}>
                {#if photosNeeded !== null}{photos.length}/{photosNeeded}
                  {photosNeeded === 1 ? 'photo' : 'photos'}
                {:else}{photos.length} {photos.length === 1 ? 'photo' : 'photos'}{/if}
              </span>
              <span>
                {#if longEnough}{words} {words === 1 ? 'word' : 'words'}{:else}{written}/{lengthNeeded} characters{/if}
              </span>
            </span>
          {/snippet}
        </MarkdownEditor>
        {#if !untouched}
          <label
            class="mt-1 flex shrink-0 cursor-pointer items-start gap-3 rounded-xl border-2 border-paper-edge/70 px-4 py-3 font-outfit"
          >
            <input type="checkbox" bind:checked={selfWritten} required class="mt-0.5 rounded text-ink" />
            <span>
              <span class="block text-sm text-ink">I wrote the above myself, by hand, without using AI.</span>
              <span class="block text-xs text-ink-soft">
                Imperfect English is a lot more powerful than soulless AI text.
              </span>
            </span>
          </label>
        {/if}
      </section>

      <aside class="mt-6 flex flex-col lg:mt-0 lg:min-h-0">
        <div class="flex flex-1 flex-col gap-5 lg:min-h-0">
          {#if !locked || form.lapse_timelapses.length > 0}
            <LapsePicker
              {lapse}
              {locked}
              current={journal?.lapse_timelapses}
              bind:selected={form.lapse_timelapses}
              returnTo={`${projectRoute(project.id).url}#write`}
              error={form.errors.lapse_timelapses}
            />
          {/if}

          <div class="shrink-0">
            <div class="flex items-center justify-between gap-3">
              <label for="journal-duration" class="font-display text-xl text-ink">Hours</label>
              <span class="flex items-baseline gap-1.5">
                <input
                  id="journal-duration"
                  bind:this={durationInput}
                  type="text"
                  bind:value={form.duration}
                  placeholder={timelapsed ? 'auto' : '1.5'}
                  inputmode="decimal"
                  readonly={locked}
                  required={!timelapsed && !locked}
                  aria-describedby="duration-help"
                  class="hours-input"
                />
                <span class="font-outfit text-sm text-ink-soft">h</span>
              </span>
            </div>
            {#if form.errors.duration || locked || autoFilled || timelapsed}
              <p id="duration-help" class="mt-1 font-outfit text-xs text-ink-soft">
                {#if form.errors.duration}<span class="text-red-700">{form.errors.duration}</span>
                {:else if locked}Hours can't be changed once logged.
                {:else if autoFilled}Filled in from {offered > tracked
                    ? 'your timelapses'
                    : 'the time you tracked'}.
                {:else}Leave it empty to use your timelapses' time.{/if}
              </p>
            {/if}
          </div>
        </div>

        <!-- Room for the button's press-down edge and focus ring, which the scrolling grid would clip. -->
        <!-- The reason sits on the wrapper because disabled buttons don't get hovered in every browser. -->
        <div
          class="mt-4 border-t-2 border-dashed border-paper-edge/70 px-1.5 pt-4 pb-2"
          title={form.processing || checking ? undefined : (blocker ?? undefined)}
        >
          <SubmitButton
            busy={form.processing || checking || hoursCheck || reminder !== null}
            disabled={!canSubmit}
            busyLabel={editing ? 'Saving' : 'Logging'}
            label={uploading ? 'Waiting for photos…' : editing ? 'Save journal' : 'Log journal'}
          />
        </div>
      </aside>
    </div>
  </form>
</Sketchbook>

{#if hoursCheck}
  <HoursCheckDialog
    hours={hoursText}
    onEdit={editHours}
    onconfirm={() => {
      hoursCheck = false
      checkThenPost()
    }}
  />
{/if}

{#if reminder}
  <WritingCheckDialog
    onEdit={editFlagged}
    onconfirm={() => {
      const id = reminder?.checkId
      reminder = null
      post(id, true)
    }}
  />
{/if}

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
  .paste-hint {
    color: var(--color-ink-soft);
    opacity: 0.6;
  }
  .paste-hint:global(.flash) {
    animation: paste-hint-flash 3s ease;
  }
  @keyframes paste-hint-flash {
    15% {
      opacity: 1;
      color: var(--color-hc-red);
    }
  }
  .hours-input:focus {
    border-color: var(--sb-ring);
    outline: none;
    box-shadow: none;
  }
</style>
