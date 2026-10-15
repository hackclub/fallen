<script lang="ts">
  import Markdown from '@/components/Markdown.svelte'
  import { uploadImage, type UploadedImage } from '@/lib/uploads'

  let {
    value = $bindable(''),
    directUploadUrl,
    onUpload,
    onError,
    placeholder = '',
  }: {
    value: string
    directUploadUrl: string
    onUpload: (image: UploadedImage) => void
    onError: (message: string) => void
    placeholder?: string
  } = $props()

  let textarea: HTMLTextAreaElement | undefined = $state()
  let preview = $state(false)
  let dragging = $state(false)
  let uploading = $state(0)

  type Tool = {
    label: string
    title: string
    apply: (s: string, start: number, end: number) => [string, number, number]
  }

  const wrap =
    (before: string, after = before) =>
    (s: string, start: number, end: number): [string, number, number] => {
      const selected = s.slice(start, end) || 'text'
      return [
        s.slice(0, start) + before + selected + after + s.slice(end),
        start + before.length,
        start + before.length + selected.length,
      ]
    }

  const linePrefix =
    (prefix: string) =>
    (s: string, start: number, end: number): [string, number, number] => {
      const lineStart = s.lastIndexOf('\n', start - 1) + 1
      const block = s.slice(lineStart, end)
      const lines = block
        .split('\n')
        .map((line) => (line.startsWith(prefix) ? line.slice(prefix.length) : prefix + line))
      const next = lines.join('\n')
      return [s.slice(0, lineStart) + next + s.slice(end), lineStart, lineStart + next.length]
    }

  const tools: Tool[] = [
    { label: 'B', title: 'Bold', apply: wrap('**') },
    { label: 'I', title: 'Italic', apply: wrap('_') },
    { label: 'H', title: 'Heading', apply: linePrefix('## ') },
    { label: '•', title: 'List', apply: linePrefix('- ') },
    { label: '<>', title: 'Code', apply: wrap('`') },
    {
      label: 'link',
      title: 'Link',
      apply: (s, start, end) => {
        const selected = s.slice(start, end) || 'text'
        const insert = `[${selected}](https://)`
        const urlStart = start + selected.length + 3
        return [s.slice(0, start) + insert + s.slice(end), urlStart, urlStart + 8]
      },
    },
  ]

  function run(tool: Tool) {
    if (!textarea) return
    const [next, selStart, selEnd] = tool.apply(value, textarea.selectionStart, textarea.selectionEnd)
    value = next
    requestAnimationFrame(() => {
      textarea?.focus()
      textarea?.setSelectionRange(selStart, selEnd)
    })
  }

  function insertAtCursor(text: string) {
    const pos = textarea?.selectionStart ?? value.length
    const before = value.slice(0, pos)
    const needsNewline = before.length > 0 && !before.endsWith('\n')
    value = before + (needsNewline ? '\n' : '') + text + '\n' + value.slice(pos)
  }

  export async function addFiles(files: FileList | File[]) {
    for (const file of Array.from(files)) {
      uploading += 1
      try {
        const image = await uploadImage(file, directUploadUrl)
        insertAtCursor(`![${image.filename}](${image.url})`)
        onUpload(image)
      } catch (error) {
        onError(error instanceof Error ? error.message : 'Upload failed')
      } finally {
        uploading -= 1
      }
    }
  }

  function onDrop(event: DragEvent) {
    event.preventDefault()
    dragging = false
    if (event.dataTransfer?.files.length) addFiles(event.dataTransfer.files)
  }

  function onPaste(event: ClipboardEvent) {
    const files = Array.from(event.clipboardData?.files ?? []).filter((f) => f.type.startsWith('image/'))
    if (files.length === 0) return
    event.preventDefault()
    addFiles(files)
  }

  function onKeydown(event: KeyboardEvent) {
    if (!(event.metaKey || event.ctrlKey)) return
    const tool =
      event.key === 'b' ? tools[0] : event.key === 'i' ? tools[1] : event.key === 'k' ? tools[5] : null
    if (!tool) return
    event.preventDefault()
    run(tool)
  }

  let fileInput: HTMLInputElement | undefined = $state()

  export function pickFiles() {
    fileInput?.click()
  }
</script>

<div class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl bg-paper-well">
  <div class="flex items-center gap-1 border-b border-ink/10 px-2 py-1.5">
    {#each tools as tool (tool.title)}
      <button
        type="button"
        title={tool.title}
        onclick={() => run(tool)}
        class="rounded-lg px-2 py-1 font-outfit text-xs font-semibold text-ink-soft hover:bg-ink/10 hover:text-ink {tool.label ===
        'I'
          ? 'italic'
          : ''}"
      >
        {tool.label}
      </button>
    {/each}
    <button
      type="button"
      title="Add a photo"
      onclick={() => fileInput?.click()}
      class="rounded-lg px-2 py-1 font-outfit text-xs font-semibold text-ink-soft hover:bg-ink/10 hover:text-ink"
    >
      photo
    </button>
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
    <span class="ml-auto flex items-center gap-2 font-outfit text-xs text-ink-soft">
      {#if uploading > 0}<span>uploading {uploading}…</span>{/if}
      <button
        type="button"
        onclick={() => (preview = !preview)}
        class="rounded-lg px-2 py-1 hover:bg-ink/10 hover:text-ink"
      >
        {preview ? 'write' : 'preview'}
      </button>
    </span>
  </div>

  {#if preview}
    <div class="min-h-[280px] flex-1 overflow-y-auto px-4 py-3">
      {#if value.trim()}
        <Markdown source={value} />
      {:else}
        <p class="font-outfit text-sm text-ink-soft/60">Nothing to preview yet.</p>
      {/if}
    </div>
  {:else}
    <div
      class="relative flex min-h-[280px] flex-1 flex-col"
      role="presentation"
      ondragover={(e) => {
        e.preventDefault()
        dragging = true
      }}
      ondragleave={() => (dragging = false)}
      ondrop={onDrop}
    >
      <textarea
        bind:this={textarea}
        bind:value
        {placeholder}
        onpaste={onPaste}
        onkeydown={onKeydown}
        class="flex-1 resize-none border-0 bg-transparent px-4 py-3 font-outfit text-[15px] leading-relaxed text-ink placeholder:text-ink-soft/50 focus:ring-0"
      ></textarea>
      {#if dragging}
        <div
          class="pointer-events-none absolute inset-1 flex items-center justify-center rounded-lg border-2 border-dashed border-ink/50 bg-paper/80 font-outfit text-sm text-ink"
        >
          Drop photos to add them
        </div>
      {/if}
    </div>
  {/if}
</div>
