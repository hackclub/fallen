<script lang="ts">
  import Modal from '@/components/Modal.svelte'
  import ModalButton from '@/components/ModalButton.svelte'

  // Shown over the composer before logging more than HOURS_REMINDER_MINUTES: a reminder to report hours honestly.
  // The composer handles Escape.
  let { hours, onEdit, onconfirm }: { hours: string; onEdit: () => void; onconfirm: () => void } = $props()

  // The composer is a stacking context of its own; on <body> this sits above it.
  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return () => node.remove()
  }
</script>

<div class="contents" {@attach portal}>
  <Modal titleId="hours-check-title" title="Logging {hours}h" onClose={onEdit} class="max-w-lg">
    <div class="px-5 pt-2 pb-6 text-center font-outfit md:px-9 md:pb-8">
      <p class="text-base text-ink">Please be truthful about reporting your hours.</p>
      <p class="mt-3 text-base text-ink">We might deflate your XP if you're not being truthful.</p>

      <div class="mt-6 flex flex-col-reverse items-center justify-center gap-3 sm:flex-row">
        <ModalButton kind="cancel" onclick={onEdit}>Change my hours</ModalButton>
        <ModalButton kind="confirm" onclick={onconfirm} autofocus>My hours are right</ModalButton>
      </div>
    </div>
  </Modal>
</div>
