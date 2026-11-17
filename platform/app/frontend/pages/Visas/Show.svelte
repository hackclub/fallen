<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  import type { Snippet } from 'svelte'
  import Accordion from '@/components/Accordion.svelte'
  import PageTitle from '@/components/PageTitle.svelte'
  import VisaChecker from '@/components/VisaChecker.svelte'
  import { docs } from '@/routes'

  const faqs: { question: string; answer: Snippet }[] = [
    { question: 'Will Fallen cover my visa?', answer: cost },
    { question: "I'm under 18. Do I need anything extra?", answer: minors },
    { question: 'My passport expires soon. Is that a problem?', answer: expiring },
  ]
</script>

{#snippet link(href: string, label: string)}
  <a {href} class="text-cream underline decoration-gold/60 underline-offset-3">{label}</a>
{/snippet}

{#snippet cost()}
  Yes, through your travel stipend. Read more in {@render link(
    docs.show({ page: 'travel-stipends' }).url,
    'Travel Stipends',
  )}.
{/snippet}

{#snippet minors()}
  Not to get into China: border officers don't check for a parent's permission. If you're applying for a visa,
  though, the visa center will ask for more, usually your birth certificate and a signed letter from your
  parents saying they're OK with the trip. Check your visa center's list.
{/snippet}

{#snippet expiring()}
  It might be. China asks for at least 6 months left on your passport to get a visa, and airlines often check
  it too. If yours runs out before June 2027, renew it first.
{/snippet}

<svelte:head><title>Visa · Fallen</title></svelte:head>

<PageTitle title="Visa" />

<div class="max-w-2xl space-y-8 font-outfit text-base leading-relaxed text-pale-blue">
  <VisaChecker />

  <section aria-labelledby="visa-faq">
    <h2 id="visa-faq" class="mb-3 px-1 font-display text-3xl text-white">FAQ</h2>
    <Accordion items={faqs} size="md" />
  </section>

  <p class="px-1 text-sm text-pale-blue/80">
    Still not sure? Email {@render link('mailto:fallen@hackclub.com', 'fallen@hackclub.com')}.
  </p>
</div>
