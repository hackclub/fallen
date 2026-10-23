<script lang="ts">
  import Bold from '@lucide/svelte/icons/bold'
  import Code from '@lucide/svelte/icons/code'
  import ImagePlus from '@lucide/svelte/icons/image-plus'
  import Italic from '@lucide/svelte/icons/italic'
  import Link from '@lucide/svelte/icons/link'
  import List from '@lucide/svelte/icons/list'
  import ListOrdered from '@lucide/svelte/icons/list-ordered'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import Strikethrough from '@lucide/svelte/icons/strikethrough'
  import type { Editor } from '@tiptap/core'
  import { onMount, type Component, type Snippet } from 'svelte'
  import type { reservePhoto } from '@/lib/journal-editor'
  import { uploadImage, type UploadedImage } from '@/lib/uploads'

  // Writes like a rich text box and stores Markdown, which is what the site renders and Slack gets a copy of.
  let {
    labelledby,
    value = $bindable(''),
    directUploadUrl,
    onUpload,
    onError,
    placeholder = '',
    uploading = $bindable(0),
    footer,
  }: {
    labelledby?: string
    value: string
    directUploadUrl: string
    onUpload: (image: UploadedImage) => void
    onError: (message: string) => void
    placeholder?: string
    uploading?: number
    // A status strip under the writing, inside the box.
    footer?: Snippet
  } = $props()

  let mount: HTMLDivElement | undefined = $state()
  let fileInput: HTMLInputElement | undefined = $state()
  let editor: Editor | undefined = $state.raw()
  let reserve: typeof reservePhoto | undefined
  // Tiptap's editor isn't reactive; this ticks on every transaction so the toolbar re-reads it.
  let redraws = $state(0)
  let dragging = $state(false)
  // Chrome marks a dragged <img> as carrying files, so a photo moved within the writing looks like one dropped in.
  let movingInside = false
  let linking = $state(false)
  let linkUrl = $state('')
  // What the editor last wrote, so a change from outside (a restored draft, a removed photo) is told apart.
  let written = value

  onMount(() => {
    let destroyed = false
    import('@/lib/journal-editor').then(({ createJournalEditor, reservePhoto }) => {
      if (destroyed || !mount) return
      reserve = reservePhoto
      editor = createJournalEditor({
        element: mount,
        markdown: value,
        placeholder,
        onChange: (markdown) => (value = written = markdown.trimEnd()),
        onRedraw: () => redraws++,
        onFiles: addFiles,
      })
      if (labelledby) editor.view.dom.setAttribute('aria-labelledby', labelledby)
    })
    return () => {
      destroyed = true
      editor?.destroy()
    }
  })

  $effect(() => {
    if (!editor || value === written) return
    written = value
    editor.commands.setContent(value, { contentType: 'markdown', emitUpdate: false })
  })

  type Tool = {
    label: string
    keys: string
    icon: Component
    active: string
    run: (e: Editor) => void
  }

  const tools: Tool[][] = [
    [
      {
        label: 'Bold',
        keys: 'B',
        icon: Bold,
        active: 'bold',
        run: (e) => e.chain().focus().toggleBold().run(),
      },
      {
        label: 'Italic',
        keys: 'I',
        icon: Italic,
        active: 'italic',
        run: (e) => e.chain().focus().toggleItalic().run(),
      },
      {
        label: 'Strikethrough',
        keys: 'Shift S',
        icon: Strikethrough,
        active: 'strike',
        run: (e) => e.chain().focus().toggleStrike().run(),
      },
      {
        label: 'Code',
        keys: 'E',
        icon: Code,
        active: 'code',
        run: (e) => e.chain().focus().toggleCode().run(),
      },
      { label: 'Link', keys: 'K', icon: Link, active: 'link', run: () => openLink() },
    ],
    [
      {
        label: 'Bulleted list',
        keys: 'Shift 8',
        icon: List,
        active: 'bulletList',
        run: (e) => e.chain().focus().toggleBulletList().run(),
      },
      {
        label: 'Numbered list',
        keys: 'Shift 7',
        icon: ListOrdered,
        active: 'orderedList',
        run: (e) => e.chain().focus().toggleOrderedList().run(),
      },
    ],
  ]

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl '

  function isActive(name: string) {
    void redraws
    return editor?.isActive(name) ?? false
  }

  function openLink() {
    if (!editor) return
    linkUrl = editor.getAttributes('link').href ?? ''
    linking = true
  }

  function closeLink() {
    linking = false
    editor?.view.focus()
  }

  function applyLink() {
    if (!editor) return
    const typed = linkUrl.trim()
    const href = typed && !/^[a-z][a-z\d+.-]*:/i.test(typed) ? `https://${typed}` : typed
    const chain = editor.chain().focus().extendMarkRange('link')
    if (!href) chain.unsetLink().run()
    else if (editor.state.selection.empty && !editor.isActive('link'))
      chain.insertContent({ type: 'text', text: typed, marks: [{ type: 'link', attrs: { href } }] }).run()
    else chain.setLink({ href }).run()
    closeLink()
  }

  // Every photo gets its spot straight away; they upload one at a time so they land in the order they came.
  export async function addFiles(files: FileList | File[], at?: number) {
    const current = editor
    if (!current || !reserve) return
    const slots = Array.from(files).map((file) => ({ file, slot: reserve!(current, file, at) }))
    uploading += slots.length
    for (const { file, slot } of slots) {
      try {
        const image = await uploadImage(file, directUploadUrl, slot.progress)
        // So the photo doesn't blink empty between the preview and the uploaded copy.
        const loaded = new Image()
        loaded.src = image.url
        await loaded.decode().catch(() => {})
        if (slot.place(image.url, image.filename)) onUpload(image)
      } catch (error) {
        slot.cancel()
        onError(error instanceof Error ? error.message : 'Upload failed')
      } finally {
        uploading -= 1
      }
    }
  }

  export function focus() {
    editor?.commands.focus('end')
  }

  export function pickFiles() {
    fileInput?.click()
  }

  function onKeydown(event: KeyboardEvent) {
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault()
      openLink()
    }
  }
</script>

<!-- The whole box takes dropped files. ProseMirror handles a drop onto the writing; anything it leaves, like a drop
     under the last line or on the toolbar, would otherwise make the browser open the file. -->
<div
  role="presentation"
  ondragstart={() => (movingInside = true)}
  ondragend={() => (movingInside = false)}
  ondragover={(e) => {
    if (movingInside || !e.dataTransfer?.types.includes('Files')) return
    e.preventDefault()
    dragging = true
  }}
  ondragleave={(e) => {
    if (!e.currentTarget.contains(e.relatedTarget as Node | null)) dragging = false
  }}
  ondrop={(e) => {
    dragging = false
    movingInside = false
    const files = e.dataTransfer?.files
    if (e.defaultPrevented || !files?.length) return
    e.preventDefault()
    addFiles(files, editor?.state.doc.content.size)
  }}
  class="relative flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl border-2 border-paper-edge bg-paper-well transition-colors focus-within:border-[var(--sb-ring)]"
>
  <div class="flex h-11 shrink-0 items-center gap-0.5 border-b-2 border-paper-edge/60 px-1.5">
    {#if linking}
      <div class="flex flex-1 items-center gap-2 pl-1.5">
        <Link class="size-4 shrink-0 text-ink-soft" />
        <input
          {@attach (input) => input.select()}
          bind:value={linkUrl}
          type="text"
          inputmode="url"
          placeholder="Paste a link"
          aria-label="Link address"
          onkeydown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              applyLink()
            } else if (e.key === 'Escape') {
              e.stopPropagation()
              closeLink()
            }
          }}
          class="min-w-0 flex-1 border-0 bg-transparent p-0 font-outfit text-sm text-ink placeholder:text-ink-soft/50 focus:ring-0"
        />
        <button type="button" class="tool-text" onclick={applyLink}
          >{linkUrl.trim() ? 'Apply' : 'Remove'}</button
        >
        <button type="button" class="tool-text" onclick={closeLink}>Cancel</button>
      </div>
    {:else}
      {#each tools as group, i (i)}
        {#if i > 0}<span class="mx-1 h-5 w-px bg-paper-edge/70" aria-hidden="true"></span>{/if}
        {#each group as tool (tool.label)}
          <button
            type="button"
            class="tool"
            aria-label={tool.label}
            aria-pressed={isActive(tool.active)}
            title="{tool.label} ({mod}{tool.keys})"
            disabled={!editor}
            onclick={() => editor && tool.run(editor)}
          >
            <tool.icon class="size-4" strokeWidth={2.4} />
          </button>
        {/each}
      {/each}
      <span class="mx-1 h-5 w-px bg-paper-edge/70" aria-hidden="true"></span>
      <button type="button" class="tool" aria-label="Add a photo" title="Add a photo" onclick={pickFiles}>
        <ImagePlus class="size-4" strokeWidth={2.4} />
      </button>
      {#if uploading > 0}
        <span class="ml-auto flex items-center gap-1.5 pr-2 font-outfit text-xs text-ink-soft">
          <LoaderCircle class="size-3.5 animate-spin" />
          Uploading {uploading === 1 ? 'a photo' : `${uploading} photos`}
        </span>
      {/if}
    {/if}
    <input
      bind:this={fileInput}
      type="file"
      accept="image/png,image/jpeg,image/gif,image/webp"
      multiple
      class="hidden"
      onchange={(e) => {
        const input = e.currentTarget
        if (input.files?.length) addFiles(input.files)
        input.value = ''
      }}
    />
  </div>

  <div class="ruled relative min-h-[280px] flex-1 overflow-y-auto" role="presentation" onkeydown={onKeydown}>
    <div bind:this={mount} class="min-h-full"></div>
  </div>
  {#if footer}
    <div
      class="flex h-9 shrink-0 items-center justify-between gap-3 border-t-2 border-paper-edge/60 bg-paper-edge/50 px-3 font-outfit text-xs text-ink-soft"
    >
      {@render footer()}
    </div>
  {/if}
  {#if dragging}
    <div
      class="pointer-events-none absolute inset-1 flex items-center justify-center rounded-lg border-2 border-dashed border-ink/50 bg-paper/80 font-outfit text-sm text-ink"
    >
      Drop photos to add them
    </div>
  {/if}
</div>

<style>
  .tool {
    display: flex;
    width: 2rem;
    height: 2rem;
    align-items: center;
    justify-content: center;
    border-radius: 0.5rem;
    color: var(--color-ink-soft);
    transition:
      background-color 120ms,
      color 120ms;
  }
  .tool:hover:not(:disabled) {
    background: color-mix(in srgb, var(--color-ink) 9%, transparent);
    color: var(--color-ink);
  }
  .tool[aria-pressed='true'] {
    background: color-mix(in srgb, var(--sb-ring) 18%, transparent);
    color: var(--sb-ring-deep);
  }
  .tool:disabled {
    opacity: 0.5;
  }
  .tool-text {
    border-radius: 0.5rem;
    padding: 0.25rem 0.5rem;
    font-family: var(--font-outfit);
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--color-ink-soft);
  }
  .tool-text:hover {
    background: color-mix(in srgb, var(--color-ink) 9%, transparent);
    color: var(--color-ink);
  }

  /* Everything sits on a 28px line so the ruling under it stays true, photos included. */
  /* Lines under the text, one per line of it, that scroll with it. */
  .ruled {
    background-image: linear-gradient(transparent 27px, rgba(204, 141, 68, 0.28) 27px);
    background-size: 100% 28px;
    background-position: 0 2px;
    background-attachment: local;
  }
  .min-h-full :global(.journal-editor) {
    padding: 5px 1rem 0.75rem;
    color: var(--color-ink);
    font-family: var(--font-outfit);
    font-size: 15px;
    line-height: 28px;
    outline: none;
    overflow-wrap: anywhere;
  }
  .min-h-full :global(.journal-editor > * + *) {
    margin-top: 0;
  }
  .min-h-full :global(.journal-editor p.is-editor-empty:first-child::before) {
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
    color: color-mix(in srgb, var(--color-ink-soft) 50%, transparent);
  }
  .min-h-full :global(.journal-editor strong) {
    font-weight: 700;
  }
  .min-h-full :global(.journal-editor a) {
    color: var(--sb-ring-deep);
    text-decoration: underline;
    text-decoration-color: color-mix(in srgb, var(--sb-ring-deep) 40%, transparent);
    text-underline-offset: 3px;
  }
  .min-h-full :global(.journal-editor code) {
    border-radius: 0.25rem;
    background: color-mix(in srgb, var(--color-ink) 9%, transparent);
    padding: 0.1rem 0.3rem;
    font-family: var(--font-mono);
    font-size: 13px;
  }
  .min-h-full :global(.journal-editor pre) {
    border-radius: 0.5rem;
    background: color-mix(in srgb, var(--color-ink) 7%, transparent);
    padding: 0 0.75rem;
    overflow-x: auto;
  }
  .min-h-full :global(.journal-editor pre code) {
    background: none;
    padding: 0;
  }
  .min-h-full :global(.journal-editor ul) {
    list-style: disc;
    padding-left: 1.4rem;
  }
  .min-h-full :global(.journal-editor ol) {
    list-style: decimal;
    padding-left: 1.4rem;
  }
  .min-h-full :global(.journal-editor li::marker) {
    color: var(--color-ink-soft);
  }
  .min-h-full :global(.journal-editor h1),
  .min-h-full :global(.journal-editor h2),
  .min-h-full :global(.journal-editor h3) {
    font-family: var(--font-display);
    font-size: 1.15rem;
  }
  .min-h-full :global(.journal-editor blockquote) {
    border-left: 2px solid color-mix(in srgb, var(--color-ink) 30%, transparent);
    padding-left: 0.75rem;
    color: var(--color-ink-soft);
  }
  .min-h-full :global(.journal-editor hr) {
    margin: 13px 0;
    border: 0;
    border-top: 2px dashed var(--color-paper-edge);
  }
  .min-h-full :global(.journal-editor img) {
    display: block;
    height: 196px;
    max-width: 100%;
    border-radius: 0.5rem;
    object-fit: cover;
  }
  .min-h-full :global(.journal-upload) {
    position: relative;
    display: block;
    width: fit-content;
    max-width: 100%;
  }
  .min-h-full :global(.journal-upload img) {
    opacity: 0.55;
  }
  .min-h-full :global(.journal-upload-status) {
    position: absolute;
    inset: auto 0.5rem 0.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    border-radius: 0.5rem;
    background: color-mix(in srgb, var(--color-paper) 92%, transparent);
    padding: 0.35rem 0.6rem 0.5rem;
    font-size: 12px;
    font-weight: 600;
    line-height: 1.2;
    font-variant-numeric: tabular-nums;
  }
  .min-h-full :global(.journal-upload-bar) {
    height: 4px;
    overflow: hidden;
    border-radius: 9999px;
    background: color-mix(in srgb, var(--color-ink) 15%, transparent);
  }
  .min-h-full :global(.journal-upload-bar > span) {
    display: block;
    width: 0;
    height: 100%;
    background: var(--sb-ring-deep);
    transition: width 150ms;
  }
  .min-h-full :global(.journal-editor img.ProseMirror-selectednode) {
    outline: 3px solid var(--sb-ring);
  }
</style>
