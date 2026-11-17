<script lang="ts">
  import Modal from '@/components/Modal.svelte'
  import ModalButton from '@/components/ModalButton.svelte'
  import { INVITATION_FORM, INVITATION_WAIT } from '@/lib/chinaVisa'

  // The invitation letter offer under a "you need a visa" answer. Where China approves most applications anyway
  // (the countries that can use visa-free transit, like the US), we suggest applying without one, and the button
  // asks once more before opening the form.
  let { likelyApproved }: { likelyApproved: boolean } = $props()

  let confirming = $state(false)
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && (confirming = false)} />

{#if likelyApproved}
  <p>
    Our Chinese partner at Maker Faire Shenzhen can issue invitation letters to help with your visa
    application. Since China approves most visa applications from your country, the Fallen team recommends
    applying without one. If your circumstances still require one, fill out the form:
  </p>
{:else}
  <p>
    We recognize that some of you might want a visa invitation letter to help with your visa application. You
    can request one here. It currently takes about {INVITATION_WAIT}.
  </p>
{/if}

<div class="pt-1">
  {#if likelyApproved}
    <button type="button" class="game-btn game-btn-blue" onclick={() => (confirming = true)}>
      Request an invitation letter
    </button>
  {:else}
    <a href={INVITATION_FORM} target="_blank" rel="noreferrer" class="game-btn game-btn-blue no-underline!">
      Request an invitation letter
    </a>
  {/if}
</div>

{#if confirming}
  <Modal
    titleId="invitation-title"
    title="Are you sure?"
    onClose={() => (confirming = false)}
    class="max-w-md"
  >
    <div class="px-5 pt-2 pb-6 font-outfit text-ink md:px-9 md:pb-8">
      <p>
        China approves most visa applications from your country without an invitation letter, so you probably
        don't need one.
      </p>
      <div class="mt-6 flex flex-wrap justify-end gap-3">
        <ModalButton kind="cancel" onclick={() => (confirming = false)}>Never mind</ModalButton>
        <a
          href={INVITATION_FORM}
          target="_blank"
          rel="noreferrer"
          class="game-btn game-btn-blue min-w-40 no-underline!"
          onclick={() => (confirming = false)}>I still need one</a
        >
      </div>
    </div>
  </Modal>
{/if}
