<script lang="ts">
  import { useForm } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import MarkdownEditor from '@/components/MarkdownEditor.svelte'
  import { countWords } from '@/lib/markdown'
  import type { UploadedImage } from '@/lib/uploads'
  import { journals, projectJournals } from '@/routes'
  import type { Journal, Project } from '@/types'

  let {
    project,
    journal = null,
    directUploadUrl,
    onClose,
  }: {
    project: Project
    journal?: Journal | null
    directUploadUrl: string
    onClose: () => void
  } = $props()

  // svelte-ignore state_referenced_locally
  const draftKey = `fallen:journal-draft:${project.id}`
  // svelte-ignore state_referenced_locally
  const editing = journal !== null

  // svelte-ignore state_referenced_locally
  const form = useForm({
    body: journal?.body ?? '',
    duration: journal?.duration_text ?? '',
    lapse_url: journal?.lapse_url ?? '',
    images: (journal?.images ?? []) as UploadedImage[],
  })

  let editor: MarkdownEditor | undefined = $state()
  let uploadError: string | null = $state(null)
  let draftRestored = $state(false)

  onMount(() => {
    if (editing) return
    try {
      const draft = localStorage.getItem(draftKey)
      if (draft) {
        const parsed = JSON.parse(draft)
        form.body = parsed.body ?? ''
        form.duration = parsed.duration ?? ''
        form.lapse_url = parsed.lapse_url ?? ''
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
      lapse_url: form.lapse_url,
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
  const canSubmit = $derived(form.body.trim().length > 0 && !form.processing)

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

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-sky-night/80 p-3 backdrop-blur-sm sm:p-6"
  role="dialog"
  aria-modal="true"
>
  <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}></button>

  <form
    onsubmit={submit}
    class="paper relative flex max-h-full w-full max-w-5xl flex-col overflow-hidden lg:h-[min(760px,100%)]"
    aria-labelledby="composer-title"
  >
    <div class="flex items-start justify-between gap-4 border-b border-paper-edge px-5 py-4 sm:px-7">
      <div>
        <p class="font-outfit text-xs tracking-wide text-ink-soft uppercase">
          {editing ? 'Editing a journal for' : 'Journaling for'}
        </p>
        <h2 id="composer-title" class="font-display text-2xl text-ink">{project.title}</h2>
      </div>
      <button type="button" onclick={onClose} class="btn-paper px-3 py-1.5 text-xs">Close</button>
    </div>

    <div class="grid min-h-0 flex-1 overflow-y-auto lg:grid-cols-[1fr_300px] lg:overflow-hidden">
      <section class="flex min-h-0 flex-col gap-2 px-5 py-4 sm:px-7 lg:border-r lg:border-paper-edge">
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

      <aside class="flex flex-col gap-5 bg-ink/[0.04] px-5 py-4 sm:px-7 lg:overflow-y-auto">
        <div>
          <p class="font-display text-lg text-ink">Time spent</p>
          <p class="mb-2 font-outfit text-xs text-ink-soft">However you'd write it: 1h 30m, 2.5, 45m.</p>
          <input type="text" bind:value={form.duration} placeholder="1h 30m" class="paper-input" />
          {#if form.errors.duration}<p class="mt-1 font-outfit text-xs text-red-700">
              {form.errors.duration}
            </p>{/if}
        </div>

        <div>
          <p class="font-display text-lg text-ink">
            Timelapse <span class="font-outfit text-xs text-ink-soft">optional</span>
          </p>
          <p class="mb-2 font-outfit text-xs text-ink-soft">A Lapse link if you recorded the session.</p>
          <input
            type="url"
            bind:value={form.lapse_url}
            placeholder="https://lapse.hackclub.com/..."
            class="paper-input"
          />
          {#if form.errors.lapse_url}<p class="mt-1 font-outfit text-xs text-red-700">
              {form.errors.lapse_url}
            </p>{/if}
        </div>

        <div>
          <p class="font-display text-lg text-ink">Photos</p>
          <p class="mb-2 font-outfit text-xs text-ink-soft">
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
                <li
                  class="group relative aspect-square overflow-hidden rounded-sm border border-paper-edge bg-white"
                >
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
          <button type="submit" class="btn-ink flex-1 py-2.5" disabled={!canSubmit}>
            {form.processing ? 'Logging…' : editing ? 'Save journal' : 'Log journal'}
          </button>
        </div>
        <p class="font-outfit text-xs text-ink-soft">Posts to your project thread in Slack as you.</p>
      </aside>
    </div>
  </form>
</div>
