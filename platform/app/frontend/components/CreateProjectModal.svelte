<script lang="ts">
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'
  import { tour } from '@/lib/tour.svelte'

  let { directUploadUrl, onClose }: { directUploadUrl: string | undefined; onClose: () => void } = $props()

  const form = projectForm(null)
  let root: HTMLFormElement
  // New people making their first project in onboarding are asked once whether the name is one they're happy for
  // everyone to see, since it's posted in Slack.
  let confirming = $state(false)

  // Back to the fields if the server turns the name down, so its error shows.
  $effect(() => {
    if (Object.keys(form.errors).length > 0) confirming = false
  })

  function submit(event: SubmitEvent) {
    event.preventDefault()
    if (tour.steppedAside && !confirming) {
      confirming = true
      return
    }
    saveProject(form, null, root, onClose)
  }

  function escape(event: KeyboardEvent) {
    if (event.key !== 'Escape') return
    if (confirming) confirming = false
    else onClose()
  }
</script>

<svelte:window onkeydown={escape} />

<OrnateModal
  titleId="create-project-title"
  title={confirming ? 'Is this the name?' : 'Create New Project'}
  eyebrow={confirming ? 'Double check' : 'A new adventure'}
  {onClose}
>
  <form
    bind:this={root}
    onsubmit={submit}
    novalidate
    class="max-h-[calc(90vh-130px)] overflow-x-hidden overflow-y-auto px-5 pt-2 pb-6 md:px-9 md:pb-8"
  >
    {#if confirming}
      <div class="text-center font-outfit">
        <p class="text-sm text-ink-soft">Everyone will see this name:</p>
        <p
          class="mx-auto mt-3 w-fit max-w-full rounded-2xl border-2 border-dashed border-[#2c3680] bg-[repeating-linear-gradient(115deg,#0a0e2c_0_14px,#0d1236_14px_28px)] px-7 py-4 font-outfit text-xl font-extrabold break-words text-cream md:text-2xl"
        >
          {form.title.trim()}
        </p>
        <p class="mt-4 text-sm text-ink-soft">
          It's posted in Slack with your project, where anyone can read it.
        </p>
      </div>

      <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
        <OrnateButton kind="cancel" onclick={() => (confirming = false)}>Change it</OrnateButton>
        <OrnateButton kind="confirm" type="submit" disabled={form.processing} autofocus>
          {form.processing ? 'Creating...' : 'Yes, create it'}
        </OrnateButton>
      </div>
    {:else}
      <ProjectFields {form} {directUploadUrl} brief />

      <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
        <OrnateButton kind="cancel" onclick={onClose}>Cancel</OrnateButton>
        <OrnateButton kind="confirm" type="submit" disabled={form.processing || form.title.trim() === ''}>
          {form.processing ? 'Creating...' : 'Create Project'}
        </OrnateButton>
      </div>
    {/if}
  </form>
</OrnateModal>
