<script lang="ts" module>
  export { default as layout } from '@/layouts/ReviewLayout.svelte'
</script>

<script lang="ts">
  import ReviewScreen from '@/components/review/ReviewScreen.svelte'
  import type { ReviewPage } from '@/lib/review.svelte'

  // Inertia keeps this page mounted when a decision or skip lands on the next submission, so the review is keyed on
  // the submission: the next one opens on its overview with nothing from the last one's review in it.
  let props: ReviewPage = $props()
</script>

{#key props.submission.id}
  <ReviewScreen {...props} />
{/key}
