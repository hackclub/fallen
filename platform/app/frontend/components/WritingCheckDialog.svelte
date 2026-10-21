<script lang="ts">
  import HoldButton from '@/components/HoldButton.svelte'
  import Modal from '@/components/Modal.svelte'
  import ModalButton from '@/components/ModalButton.svelte'

  // Shown over the composer when Pangram reads a journal as AI-written (WritingCheck): a reminder of the rule. The
  // easy way out is editing, and posting as is takes a long hold. The composer handles Escape.
  let { onEdit, onconfirm }: { onEdit: () => void; onconfirm: () => void } = $props()

  // The composer is a stacking context of its own; on <body> this sits above it.
  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

<div class="contents" {@attach portal}>
  <Modal titleId="writing-check-title" title="Before you post" onClose={onEdit} class="max-w-lg">
    <div class="px-5 pt-2 pb-6 text-center font-outfit md:px-9 md:pb-8">
      <p class="text-base text-ink">
        As a general reminder, you must NOT use AI to generate your journals! We don't care if your grammar is
        bad or you have a bunch of typos.
      </p>
      <p class="mt-3 text-base text-ink">
        If we do find out that a project or journal is generated using AI, it'll potentially be rejected.
      </p>

      <div class="mt-6 flex flex-col-reverse items-center justify-center gap-3 sm:flex-row">
        <HoldButton
          label="I wrote this myself"
          holding="Keep holding"
          done="Posting"
          seconds={5}
          {onconfirm}
          game
        />
        <ModalButton kind="confirm" onclick={onEdit} autofocus>Edit my journal</ModalButton>
      </div>
    </div>
  </Modal>
</div>
