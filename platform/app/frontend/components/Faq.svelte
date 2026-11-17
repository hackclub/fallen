<script lang="ts">
  // The landing page's FAQ (Accordion does the opening and closing).
  import Accordion from '@/components/Accordion.svelte'
  import { buildTime } from '@/lib/program'

  import type { Snippet } from 'svelte'

  const qualifyingHours = '80-120'

  const faqs: { question: string; answer: Snippet }[] = [
    { question: 'Who can join?', answer: whoCanJoin },
    { question: 'Is this legit?', answer: isItLegit },
    { question: "Is this really free? What's the catch?", answer: isItFree },
    { question: 'Why Shenzhen, China?', answer: whyShenzhen },
    { question: 'What do I build?', answer: whatToBuild },
    { question: 'Can I make multiple projects?', answer: multipleProjects },
    { question: 'Can I follow a tutorial?', answer: tutorials },
    { question: 'Can I work in teams?', answer: teams },
    { question: 'How long do I need to spend on my project?', answer: howLong },
    { question: "What if I can't go to Shenzhen?", answer: cantTravel },
    { question: "I've got more questions...", answer: moreQuestions },
  ]
</script>

{#snippet link(href: string, label: string)}
  <a
    {href}
    target="_blank"
    rel="noreferrer"
    class="text-cream underline decoration-gold/60 underline-offset-3">{label}</a
  >
{/snippet}

{#snippet whoCanJoin()}
  Any teenager aged 13 to 18 (inclusive)!
{/snippet}

{#snippet isItLegit()}
  Yes! {@render link('https://hackclub.com', 'Hack Club')} is a 501(c)(3) nonprofit, and we've run programs like
  {@render link('https://fallout.hackclub.com', 'Fallout')} and
  {@render link('https://outpost.hackclub.com', 'Outpost')} before.
{/snippet}

{#snippet isItFree()}
  No catch! Fallen funds your project and the in-person event.
{/snippet}

{#snippet whyShenzhen()}
  We'll be demoing our projects at Maker Faire Shenzhen, in the manufacturing capital of the world. While
  we're there, we'll visit local hardware spots like the world's largest electronics market.
{/snippet}

{#snippet whatToBuild()}
  One large hardware project (think a {buildTime} of dedicated work!). Keep in mind you'll be demoing this project
  in Shenzhen!
{/snippet}

{#snippet multipleProjects()}
  Yes, but pick one main project to focus on! You can also build smaller projects on the side to get started
  with hardware, make trinkets to hand out, or for fun!
{/snippet}

{#snippet tutorials()}
  You can learn from tutorials, but your project must be your own.
{/snippet}

{#snippet teams()}
  Yes! Invite your teammates from your project page. Each teammate needs their own clear part of the project,
  and journals their own hours to level up their own character: nothing anyone logs is split or shared.
{/snippet}

{#snippet howLong()}
  Your character levels up with the hours you put in, and you qualify once it reaches its final form.
  Journaling every day builds a streak that speeds up its progress, so qualifying takes about {qualifyingHours}
  hours depending on how well you keep your streak & your character's bonus!
{/snippet}

{#snippet cantTravel()}
  You can still be a faller! Level up your character to earn prizes like 3D printers and CNC mills, or Fallen
  merch.
{/snippet}

{#snippet moreQuestions()}
  Ask in {@render link('https://hackclub.enterprise.slack.com/archives/C0C9JQEPFL6', '#fallen-help')} on Slack or
  email us at {@render link('mailto:fallen@hackclub.com', 'fallen@hackclub.com')}!
{/snippet}

<section
  id="faq"
  class="flex flex-col justify-center gap-10 overflow-clip px-6 py-20 text-pale-blue md:px-20"
>
  <h2
    class="mx-auto font-lora text-6xl font-bold text-parchment text-shadow-md text-shadow-dark-purple/40 md:text-7xl"
  >
    FAQ
  </h2>
  <div class="place-down-stage flex justify-center gap-10">
    <div class="place-down place-down-stage mx-auto max-w-215 min-w-0 flex-1 py-12 md:px-8">
      <Accordion items={faqs} itemClass="place-down" />
    </div>
  </div>
</section>
