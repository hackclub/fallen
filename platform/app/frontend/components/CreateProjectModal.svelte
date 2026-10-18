<script lang="ts">
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import ProjectFields from '@/components/ProjectFields.svelte'
  import { projectForm, saveProject } from '@/lib/projectForm'
  import { tick } from 'svelte'
  import { shared } from '@/lib/shared.svelte'

  let { directUploadUrl, onClose }: { directUploadUrl: string | undefined; onClose: () => void } = $props()

  const form = projectForm(null)
  const user = $derived(shared().auth.user)
  let root: HTMLFormElement
  // Creating posts the project in the journals channel, so everyone sees what that post will say before it goes
  // out. People were posting throwaway names ("meow", "project") with nothing else, so a post with no description
  // steers them back to write one and makes going ahead the quieter choice.
  let confirming = $state(false)
  const bare = $derived(form.description.trim() === '')

  // Back to the fields if the server turns the name down, so its error shows.
  $effect(() => {
    if (Object.keys(form.errors).length > 0) confirming = false
  })

  function submit(event: SubmitEvent) {
    event.preventDefault()
    if (!confirming) {
      confirming = true
      return
    }
    saveProject(form, null, root, onClose)
  }

  async function addDescription() {
    confirming = false
    await tick()
    root.querySelector<HTMLElement>('[name="description"]')?.focus()
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
  title={confirming ? 'Post this to Slack?' : 'Create New Project'}
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
      <div class="font-outfit">
        <p class="text-center text-sm text-ink-soft">
          Here's the post that starts your project's thread in Slack. Everyone in the channel can read it.
        </p>
        <div
          class="mt-3 overflow-hidden rounded-xl border border-ink/15 bg-white text-left text-[#1d1c1d] shadow-sm"
        >
          <div class="border-b border-ink/10 px-4 py-2 text-sm font-bold"># fallen-journals</div>
          <div class="flex gap-3 px-4 py-3">
            {#if user}
              <img src={user.avatar} alt="" class="h-9 w-9 shrink-0 rounded-md bg-stone-200 object-cover" />
            {/if}
            <div class="min-w-0 flex-1 text-[15px] leading-snug break-words whitespace-pre-line">
              <p>
                <span class="font-bold">{user?.display_name ?? 'You'}</span>
                <span class="ml-1 text-xs text-[#616061]">now</span>
              </p>
              <p>Project name: {form.title.trim()}</p>
              {#if !bare}
                <p class="mt-3 line-clamp-6">{form.description.trim()}</p>
              {/if}
            </div>
          </div>
        </div>
        <p class="mt-4 text-center text-sm text-ink-soft">
          Every journal you post on it goes in this thread, so give it its real name. Not right yet? Change it
          now, before anything is posted.
        </p>
      </div>

      <div class="mt-6 flex flex-col-reverse justify-center gap-3 sm:flex-row md:mt-8">
        {#if bare}
          <OrnateButton kind="cancel" type="submit" disabled={form.processing}>
            {form.processing ? 'Creating...' : 'Post it anyway'}
          </OrnateButton>
          <OrnateButton kind="confirm" onclick={addDescription} autofocus>Add a description</OrnateButton>
        {:else}
          <OrnateButton kind="cancel" onclick={() => (confirming = false)}>Change it</OrnateButton>
          <OrnateButton kind="confirm" type="submit" disabled={form.processing} autofocus>
            {form.processing ? 'Creating...' : 'Yes, post it'}
          </OrnateButton>
        {/if}
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
