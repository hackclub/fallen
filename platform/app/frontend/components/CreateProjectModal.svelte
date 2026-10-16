<script lang="ts">
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'

  let { directUploadUrl, onClose }: { directUploadUrl: string | undefined; onClose: () => void } = $props()

  const form = projectForm(null)
  let root: HTMLElement

  function submit(event: SubmitEvent) {
    event.preventDefault()
    saveProject(form, null, root, onClose)
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onClose()} />

<div
  class="fixed inset-0 z-50 flex items-center justify-center overflow-auto bg-black/40 p-2 md:p-4"
  role="dialog"
  aria-modal="true"
  aria-labelledby="create-project-title"
>
  <button type="button" class="absolute inset-0 cursor-default" aria-label="Close" onclick={onClose}></button>

  <div bind:this={root} class="paper relative w-full max-w-xl shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)]">
    <div class="flex items-center justify-between border-b border-ink/10 p-3 md:p-6">
      <h2 id="create-project-title" class="font-display text-lg text-ink md:text-2xl">Create New Project</h2>
      <button
        type="button"
        onclick={onClose}
        aria-label="Close"
        class="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full text-2xl leading-none text-ink-soft hover:bg-ink/5 hover:text-ink"
      >
        ×
      </button>
    </div>

    <form
      onsubmit={submit}
      novalidate
      class="max-h-[calc(90vh-100px)] overflow-x-hidden overflow-y-auto p-3 md:p-6"
    >
      <ProjectFields {form} {directUploadUrl} brief />

      <div class="mt-4 flex justify-end gap-2 md:mt-6 md:gap-3">
        <button type="button" class="btn-paper px-5 py-2" onclick={onClose}>Cancel</button>
        <button
          type="submit"
          class="btn-ink px-5 py-2"
          disabled={form.processing || form.title.trim() === ''}
        >
          {form.processing ? 'Creating...' : 'Create Project'}
        </button>
      </div>
    </form>
  </div>
</div>
