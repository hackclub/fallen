<script lang="ts" module>
  export const PROMISES = [
    'My design is finished, and I’ve done my best to make sure it’ll work.',
    'My repository has everything someone else would need to build it.',
    'It’s my own design. If I followed a guide, I changed it and made it my own.',
    'I’ve read the submission guidelines and believe my project is ready to submit.',
  ]
</script>

<script lang="ts">
  import { docs } from '@/routes'

  let { ready = $bindable(), resubmission }: { ready: boolean[]; resubmission: boolean } = $props()
</script>

<p class="text-center text-sm text-ink-soft">
  {#if resubmission}
    Welcome back! A reviewer will look at it again, along with what they said last time.
  {:else}
    A reviewer will read your journals and repo, then fund the parts you need to build it.
  {/if}
  Most send-backs are things you can fix in five minutes, so please look over the
  <a
    href={docs.show({ page: 'submitting' }).url}
    target="_blank"
    class="font-semibold text-ink underline underline-offset-2">submission guidelines</a
  > first.
</p>

<fieldset class="mt-5">
  <legend class="mb-2 text-sm font-semibold text-ink">Is all of this true?</legend>
  <ul class="space-y-2">
    {#each PROMISES as promise, i (i)}
      <li>
        <label
          class={[
            'flex cursor-pointer items-start gap-3 rounded-xl border-2 px-3.5 py-3 text-sm transition-colors',
            ready[i] ? 'border-[#1cb0f6] bg-[#e8f7ff]' : 'border-paper-rim bg-[#fffdf8] hover:border-ink/25',
          ]}
        >
          <input
            type="checkbox"
            bind:checked={ready[i]}
            class="mt-0.5 size-4.5 shrink-0 rounded border-ink/30 text-[#1cb0f6] focus:ring-[#1cb0f6]"
          />
          <span class="text-ink">{promise}</span>
        </label>
      </li>
    {/each}
  </ul>
</fieldset>
