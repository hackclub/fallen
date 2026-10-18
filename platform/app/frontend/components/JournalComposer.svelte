<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import LapsePicker, { type LapseStatus } from '@/components/LapsePicker.svelte'
  import MarkdownEditor from '@/components/MarkdownEditor.svelte'
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import { countWords } from '@/lib/markdown'
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
  // Typed hours always count. With timelapses picked and nothing typed, the server takes their recorded time.
  const timelapsed = $derived(form.lapse_timelapses.length > 0)
  const canSubmit = $derived(
    form.body.trim().length > 0 && (timelapsed || form.duration.trim().length > 0) && !form.processing,
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

<OrnateModal
  titleId="composer-title"
  title={project.title}
  eyebrow={editing ? 'Editing a journal for' : 'Journaling for'}
  {onClose}
  class="max-w-5xl lg:h-[min(760px,100%)]"
>
  <form
    onsubmit={submit}
    class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-b-[20px] border-t-2 border-[#070b24]"
  >
    <div class="grid min-h-0 flex-1 overflow-y-auto lg:grid-cols-[1fr_300px] lg:overflow-hidden">
      <section class="flex min-h-0 flex-col gap-2 px-5 py-4 sm:px-7 lg:border-r-2 lg:border-[#070b24]">
        <label for="journal-body" class="font-display text-lg text-ink">What did you do?</label>
        <MarkdownEditor
          bind:this={editor}
          bind:value={form.body}
          {directUploadUrl}
          onUpload={addImage}
          onError={(message) => (uploadError = message)}
          placeholder="What you built, what broke, what you figured out. Drop or paste photos anywhere in here."
        />
        <div class="flex items-center justify-between font-outfit text-xs text-ink-soft">
          <span>
            {#if form.errors.body}<span class="text-red-700">{form.errors.body}</span>
            {:else if uploadError}<span class="text-red-700">{uploadError}</span>
            {:else if draftRestored}Draft restored.{/if}
          </span>
          <span>{words} {words === 1 ? 'word' : 'words'}</span>
        </div>
      </section>

      <aside class="flex flex-col gap-5 bg-black/15 px-5 py-4 sm:px-7 lg:overflow-y-auto">
        <LapsePicker
          {lapse}
          current={journal?.lapse_timelapses}
          bind:selected={form.lapse_timelapses}
          returnTo={`${projectRoute(project.id).url}#write`}
          error={form.errors.lapse_timelapses}
        />

        <div>
          <p class="font-display text-lg text-ink">Time spent (hours)</p>
          <p class="mb-2 font-outfit text-xs text-ink-soft">
            {timelapsed
              ? 'In hours. Leave it empty to use your timelapses’ time.'
              : 'Every journal needs one, in hours: 1.5, 0.5, 0.1.'}
          </p>
          <input
            type="text"
            bind:value={form.duration}
            placeholder={timelapsed ? 'From your timelapses' : '1.5'}
            inputmode="decimal"
            required={!timelapsed}
            aria-describedby={fromTracking ? 'duration-source' : undefined}
            class="paper-input"
          />
          {#if fromTracking}
            <p id="duration-source" class="mt-1 font-outfit text-xs text-ink-soft">
              (based on tracked recorded hours)
            </p>
          {/if}
          {#if form.errors.duration}<p class="mt-1 font-outfit text-xs text-red-700">
              {form.errors.duration}
            </p>{/if}
        </div>
        <p class="-mt-3 font-outfit text-xs text-ink-soft">
          If your journal isn't detailed enough, its hours might be deflated.
        </p>

        <div>
          <p class="font-display text-lg text-ink">Photos</p>
          <p class="mb-2 font-outfit text-xs text-ink-soft">
            One for every 2 hours logged.
            {form.images.length === 0
              ? 'None yet. Drop them in the editor or'
              : `${form.images.length} attached.`}
            <button type="button" class="underline hover:text-ink" onclick={() => editor?.pickFiles()}>
              {form.images.length === 0 ? 'pick a file' : 'Add more'}
            </button>
          </p>
          {#if form.images.length > 0}
            <ul class="grid grid-cols-3 gap-2">
              {#each form.images as image (image.id)}
                <li class="group relative aspect-square overflow-hidden rounded-lg bg-paper-well">
                  <img src={image.url} alt={image.filename} class="h-full w-full object-cover" />
                  <button
                    type="button"
                    aria-label="Remove {image.filename}"
                    onclick={() => removeImage(image)}
                    class="absolute top-1 right-1 hidden h-6 w-6 items-center justify-center rounded-full bg-ink text-xs text-paper group-hover:flex"
                  >
                    ×
                  </button>
                </li>
              {/each}
            </ul>
          {/if}
          {#if form.errors.images}<p class="mt-1 font-outfit text-xs text-red-700">
              {form.errors.images}
            </p>{/if}
        </div>

        <div class="mt-auto flex items-center gap-3 pt-2">
          <OrnateButton kind="confirm" type="submit" class="flex-1" disabled={!canSubmit}>
            {form.processing ? 'Logging…' : editing ? 'Save journal' : 'Log journal'}
          </OrnateButton>
        </div>
        <p class="font-outfit text-xs text-ink-soft">Posts to your project thread in Slack as you.</p>
      </aside>
    </div>
  </form>
</OrnateModal>
