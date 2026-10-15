<script lang="ts">
  import { IMAGE_TYPES, uploadImage } from '@/lib/uploads'

  // Click, drop or paste an image; it goes straight to storage and `value` becomes `{ id, url }`.
  let {
    value = $bindable(),
    directUploadUrl,
  }: {
    value: { id: string; url: string } | null
    directUploadUrl: string | undefined
  } = $props()

  let input: HTMLInputElement
  let uploading = $state(false)
  let dragging = $state(false)
  let uploadError: string | null = $state(null)

  async function take(file: File | undefined) {
    if (!file || !directUploadUrl || uploading) return
    uploading = true
    uploadError = null
    try {
      const image = await uploadImage(file, directUploadUrl)
      value = { id: image.id, url: image.url }
    } catch (e) {
      uploadError = e instanceof Error ? e.message : 'Upload failed'
    } finally {
      uploading = false
    }
  }

  function onDrop(event: DragEvent) {
    event.preventDefault()
    dragging = false
    void take(event.dataTransfer?.files[0])
  }

  // Pasting an image anywhere on the page sets the banner.
  function onPaste(event: ClipboardEvent) {
    const file = [...(event.clipboardData?.files ?? [])].find((f) => IMAGE_TYPES.includes(f.type))
    if (file) {
      event.preventDefault()
      void take(file)
    }
  }
</script>

<svelte:window onpaste={onPaste} />

<div>
  <!-- summer-of-making's banner drop zone: dashed, filled, "Upload a banner" fades in on hover. -->
  <div
    role="button"
    tabindex="0"
    aria-label={value ? 'Replace banner' : 'Upload a banner'}
    onclick={() => input.click()}
    onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), input.click())}
    ondragover={(e) => (e.preventDefault(), (dragging = true))}
    ondragleave={() => (dragging = false)}
    ondrop={onDrop}
    class="group relative h-32 w-full cursor-pointer overflow-hidden rounded-lg border-2 border-dashed bg-paper-well transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink sm:h-40 {dragging
      ? 'border-ink'
      : 'border-ink/25 hover:border-ink/60'}"
  >
    {#if value}
      <img src={value.url} alt="Banner preview" class="absolute inset-0 h-full w-full object-cover" />
    {/if}
    <div
      class="absolute inset-0 flex items-center justify-center transition-all duration-200 group-hover:bg-paper/75 {dragging ||
      uploading
        ? 'bg-paper/75'
        : ''}"
    >
      <span
        class="btn-ink px-6 py-2 transition-opacity duration-200 group-hover:opacity-100 group-focus-visible:opacity-100 {dragging ||
        uploading
          ? 'opacity-100'
          : 'opacity-0'}"
      >
        {uploading ? 'Uploading...' : dragging ? 'Drop it here' : 'Upload a banner'}
      </span>
    </div>
  </div>

  {#if uploadError || value}
    <div class="mt-1 flex items-center justify-between font-outfit text-xs">
      <span class="text-red-700">{uploadError ?? ''}</span>
      {#if value && !uploading}
        <button type="button" class="text-ink-soft hover:text-ink" onclick={() => (value = null)}
          >Remove</button
        >
      {/if}
    </div>
  {/if}

  <input
    bind:this={input}
    type="file"
    accept={IMAGE_TYPES.join(',')}
    class="hidden"
    onchange={(e) => {
      void take(e.currentTarget.files?.[0])
      e.currentTarget.value = ''
    }}
  />
</div>
