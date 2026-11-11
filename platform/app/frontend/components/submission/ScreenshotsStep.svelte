<script lang="ts">
  import { MAX_SCREENSHOTS, type Screenshot } from '@/lib/submission'
  import { IMAGE_TYPES, uploadImage } from '@/lib/uploads'

  // The pictures the reviewer sees first. The first one leads, so it should show as much of the project as it can:
  // the whole assembly, rendered.
  let {
    screenshots = $bindable(),
    uploading = $bindable(),
    directUploadUrl,
  }: { screenshots: Screenshot[]; uploading: boolean; directUploadUrl: string } = $props()

  let input: HTMLInputElement
  let dragging = $state(false)
  let error = $state<string | null>(null)
  let progress = $state(0)

  const room = $derived(MAX_SCREENSHOTS - screenshots.length)

  async function take(files: File[]) {
    const picked = files.filter((f) => IMAGE_TYPES.includes(f.type)).slice(0, room)
    if (picked.length === 0) {
      if (files.length) error = 'Screenshots must be PNG, JPEG, GIF or WebP'
      return
    }
    uploading = true
    error = null
    try {
      for (const [i, file] of picked.entries()) {
        const image = await uploadImage(file, directUploadUrl, (f) => (progress = (i + f) / picked.length))
        screenshots = [...screenshots, { id: image.id, url: image.url }]
      }
    } catch (e) {
      error = e instanceof Error ? e.message : 'Upload failed'
    } finally {
      uploading = false
      progress = 0
    }
  }

  function onPaste(event: ClipboardEvent) {
    const files = [...(event.clipboardData?.files ?? [])].filter((f) => IMAGE_TYPES.includes(f.type))
    if (files.length === 0 || room === 0) return
    event.preventDefault()
    void take(files)
  }

  function lead(index: number) {
    screenshots = [screenshots[index], ...screenshots.filter((_, i) => i !== index)]
  }
</script>

<svelte:window onpaste={onPaste} />

<p class="text-center text-sm text-ink-soft">
  Add a screenshot that shows as much of your design as you can, like a render of the whole thing put
  together. Add up to {MAX_SCREENSHOTS}: the PCB, the schematic, close-up shots, etc.
</p>

<div class="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3">
  {#each screenshots as shot, i (shot.id)}
    <figure
      class={[
        'group relative overflow-hidden rounded-xl border-2 bg-paper-well',
        i === 0 ? 'col-span-2 row-span-2 aspect-[4/3] border-[#1cb0f6]' : 'aspect-[4/3] border-paper-rim',
      ]}
    >
      <img src={shot.url} alt="Screenshot {i + 1}" class="absolute inset-0 h-full w-full object-cover" />
      {#if i === 0}
        <figcaption
          class="absolute top-2 left-2 rounded-full bg-[#1cb0f6] px-2.5 py-0.5 text-xs font-semibold text-white"
        >
          Shown first
        </figcaption>
      {/if}
      <div
        class="absolute right-2 bottom-2 flex gap-1.5 opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100"
      >
        {#if i > 0}
          <button
            type="button"
            class="rounded-full bg-white/95 px-2.5 py-1 text-xs font-semibold text-ink shadow"
            onclick={() => lead(i)}
          >
            Show first
          </button>
        {/if}
        <button
          type="button"
          class="rounded-full bg-white/95 px-2.5 py-1 text-xs font-semibold text-red-700 shadow"
          onclick={() => (screenshots = screenshots.filter((s) => s.id !== shot.id))}>Remove</button
        >
      </div>
    </figure>
  {/each}

  {#if room > 0}
    <button
      type="button"
      onclick={() => input.click()}
      ondragover={(e) => (e.preventDefault(), (dragging = true))}
      ondragleave={() => (dragging = false)}
      ondrop={(e) => {
        e.preventDefault()
        dragging = false
        void take([...(e.dataTransfer?.files ?? [])])
      }}
      disabled={uploading}
      class={[
        'flex aspect-[4/3] flex-col items-center justify-center gap-1 rounded-xl border-2 border-dashed px-3 text-center transition-colors',
        screenshots.length === 0 && 'col-span-2 row-span-2 sm:col-span-3 sm:aspect-[16/7]',
        dragging ? 'border-[#1cb0f6] bg-[#e8f7ff]' : 'border-ink/20 bg-paper-well hover:border-ink/40',
      ]}
    >
      {#if uploading}
        <span class="text-sm font-semibold text-ink">Uploading {Math.round(progress * 100)}%</span>
      {:else}
        <span class="text-2xl leading-none text-ink/40" aria-hidden="true">+</span>
        <span class="text-sm font-semibold text-ink"
          >{screenshots.length === 0 ? 'Add a screenshot' : 'Add another'}</span
        >
        <span class="text-xs text-ink-soft">Click, drop or paste</span>
      {/if}
    </button>
  {/if}
</div>

{#if error}
  <p class="mt-2 text-sm text-red-700">{error}</p>
{/if}

<input
  bind:this={input}
  type="file"
  multiple
  accept={IMAGE_TYPES.join(',')}
  class="hidden"
  onchange={(e) => {
    void take([...(e.currentTarget.files ?? [])])
    e.currentTarget.value = ''
  }}
/>
