<script lang="ts">
  import ModalButton from '@/components/ModalButton.svelte'
  import Modal from '@/components/Modal.svelte'
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'
  import type { Project } from '@/types'

  // Editing in place on the project page. Projects/Form.svelte still serves a direct visit to /projects/:id/edit.
  let {
    project,
    directUploadUrl,
    onClose,
  }: { project: Project; directUploadUrl: string | undefined; onClose: () => void } = $props()

  // svelte-ignore state_referenced_locally
  const form = projectForm(project)
  let root: HTMLFormElement

  function submit(event: SubmitEvent) {
    event.preventDefault()
    saveProject(form, project, root, onClose, { preserveScroll: true })
  }
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onClose()} />

<Modal titleId="edit-project-title" title="Edit Project" {onClose}>
  <form
    bind:this={root}
    onsubmit={submit}
    novalidate
    class="max-h-[calc(90vh-130px)] overflow-x-hidden overflow-y-auto px-5 pt-2 pb-6 md:px-9 md:pb-8"
  >
    <ProjectFields {form} {directUploadUrl} banner={false} />

    <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
      <ModalButton kind="cancel" onclick={onClose}>Cancel</ModalButton>
      <ModalButton kind="confirm" type="submit" disabled={form.processing || form.title.trim() === ''}>
        {form.processing ? 'Saving...' : 'Save'}
      </ModalButton>
    </div>
  </form>
</Modal>
