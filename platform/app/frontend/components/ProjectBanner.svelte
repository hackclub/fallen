<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { IMAGE_TYPES, uploadImage } from '@/lib/uploads'
  import { projects } from '@/routes'
  import type { Project } from '@/types'
  import defaultBanner from '@/assets/hero/default-banner.jpg'

  // The top of the project page, after summer-of-making's: the picture fades into the glass below it, and the owner
  // can click, drag or paste an image onto it to replace the banner.
  let {
    project,
    editable,
    directUploadUrl,
  }: { project: Project; editable: boolean; directUploadUrl: string | undefined } = $props()

  let input: HTMLInputElement | undefined = $state()
  let dragging = $state(false)
  let uploading = $state(false)
  let error: string | null = $state(null)

  async function take(file: File | undefined) {
    if (!file || !directUploadUrl || uploading) return
    uploading = true
    error = null
    try {
      const image = await uploadImage(file, directUploadUrl)
      router.patch(
        projects.update(project.id).url,
        { project: { banner: image.id } },
        { preserveScroll: true, onFinish: () => (uploading = false) },
      )
    } catch (e) {
      error = e instanceof Error ? e.message : 'Upload failed'
      uploading = false
    }
  }

  function onPaste(event: ClipboardEvent) {
    if (!editable) return
    const file = [...(event.clipboardData?.files ?? [])].find((f) => IMAGE_TYPES.includes(f.type))
    if (file) {
      event.preventDefault()
      void take(file)
    }
  }
</script>

<svelte:window onpaste={onPaste} />

{#snippet picture()}
  <img
    src={project.cover_url ?? defaultBanner}
    alt={project.title}
    class="h-full w-full object-cover object-center [mask-image:linear-gradient(to_bottom,black_45%,transparent)]"
  />
{/snippet}

{#if editable}
  <div
    class="group relative isolate h-52 cursor-pointer overflow-hidden rounded-t-[4px] outline-none md:h-72"
    role="button"
    tabindex="0"
    aria-label="Upload a new banner"
    onclick={() => input?.click()}
    onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), input?.click())}
    ondragover={(e) => (e.preventDefault(), (dragging = true))}
    ondragleave={() => (dragging = false)}
    ondrop={(e) => {
      e.preventDefault()
      dragging = false
      void take(e.dataTransfer?.files[0])
    }}
  >
    {@render picture()}
    <div
      class="pointer-events-none absolute inset-0 z-10 flex flex-col justify-center [mask-image:linear-gradient(to_bottom,black_45%,transparent)] transition-colors duration-300 {dragging ||
      uploading
        ? 'bg-sky-night/70'
        : 'group-hover:bg-sky-night/70 group-focus-visible:bg-sky-night/70'}"
    >
      <p
        class="text-center font-montserrat font-semibold transition-colors duration-300 {dragging ||
        uploading ||
        error
          ? 'text-cream'
          : 'text-transparent group-hover:text-cream group-focus-visible:text-cream'}"
      >
        {error ??
          (uploading ? 'Uploading... hold on tight!' : 'Click, drag, or paste to upload a new banner image')}
      </p>
    </div>
  </div>
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
{:else}
  <div class="relative h-52 overflow-hidden rounded-t-[4px] md:h-72">
    {@render picture()}
  </div>
{/if}
