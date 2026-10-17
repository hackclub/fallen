<script lang="ts">
  // One card in the Past projects arc: a tangerine edge round a pale border, the photo inside a sand hairline with a
  // tangerine dot in each corner, and the project's name over a dusk gradient at the bottom. The wheel sets two things
  // on it each frame (lib/projectWheel.ts): the opacity of [data-shade], which dims the cards further out, and the mask
  // of [data-card], which fades its edge as it trades places with the card behind. The shadow sits outside the mask so
  // it never cuts it. Hovering tilts it towards the cursor (lib/holo.ts).
  import HoloShine from '@/components/HoloShine.svelte'
  import { holo } from '@/lib/holo'
  import type { PastProject } from '@/lib/pastProjects'

  let { project }: { project: PastProject } = $props()
</script>

<div
  class="absolute inset-0 rounded-lg shadow-[0_10px_20px_-10px_rgb(2_2_4/0.5),0_30px_60px_-24px_rgb(2_2_4/0.6)]"
></div>
<div
  data-card
  class="holo-card relative size-full rounded-lg border-2 border-tangerine bg-mist p-1.5"
  use:holo={{ maxTilt: 10 }}
>
  <div class="relative size-full overflow-hidden rounded-sm border border-sand/70 bg-dark-blue">
    <img src={project.image} alt="" draggable="false" loading="lazy" class="size-full object-cover" />
    <div
      class="absolute inset-0 bg-linear-to-t from-dark-purple via-dark-purple/25 via-45% to-transparent"
    ></div>
    <!-- its own layer, so changing its opacity never repaints the card under it -->
    <div data-shade class="absolute inset-0 bg-dark-blue opacity-0 will-change-[opacity]"></div>
    <span class="absolute top-2 left-2 size-1.5 rounded-full bg-tangerine"></span>
    <span class="absolute top-2 right-2 size-1.5 rounded-full bg-tangerine"></span>
    <span class="absolute bottom-2 left-2 size-1.5 rounded-full bg-tangerine"></span>
    <span class="absolute right-2 bottom-2 size-1.5 rounded-full bg-tangerine"></span>
    <p
      class="absolute inset-x-5 bottom-6 font-lora text-xl leading-tight font-bold text-cream text-shadow-md text-shadow-dark-purple sm:text-2xl"
    >
      {project.name}
    </p>
    <HoloShine rounded="rounded-sm" />
  </div>
</div>
