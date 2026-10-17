<script lang="ts">
  // The landing page's recap video, over the page's backdrop (Landing/Index.svelte). A saffron heading and
  // mint subtitle, with gold framing the video.
  import PhotoCard from '@/components/PhotoCard.svelte'
  import RecapVideo from '@/components/RecapVideo.svelte'
  import demo from '@/assets/past/02.webp'
  import fallout from '@/assets/past/21.webp'
  import group from '@/assets/past/22.webp'
  import piggyback from '@/assets/past/23.webp'
  import shark from '@/assets/past/24.webp'

  import type { ComponentProps } from 'svelte'

  // Photos from the hackathon, each card shaped to its photo. shift is in % of the card's own size; at, where needed,
  // keeps the faces in a crop. Each is washed in the same blue as the video's thumbnail (RecapVideo.svelte)
  type Photo = ComponentProps<typeof PhotoCard> & { src: string; alt: string; at?: string }
  const leftPhotos: Photo[] = [
    {
      class: 'aspect-4/3 w-60',
      rotate: 5,
      src: shark,
      alt: 'Two hackers giving a thumbs up, one hugging a toy shark',
      at: 'object-[50%_30%]',
    },
    {
      class: 'aspect-3/2 w-70',
      rotate: -2,
      src: fallout,
      alt: 'Three hackers posing outside the Fallout space',
    },
  ]
  const rightPhotos: Photo[] = [
    {
      class: 'aspect-3/4 w-40 z-30',
      rotate: 7,
      shift: [25, 0],
      src: piggyback,
      alt: 'One hacker carrying another on their shoulders',
    },
    {
      class: 'aspect-4/3 w-70',
      rotate: -4,
      shift: [0, -25],
      src: demo,
      alt: 'Hackers watching a demo on the big screen',
    },
    {
      class: 'aspect-4/3 w-80',
      rotate: 4,
      shift: [0, 33.33],
      src: group,
      alt: 'A group of hackers taking a selfie in a tea shop',
    },
  ]
</script>

<section
  id="watch"
  class="place-down-stage relative flex flex-col items-center gap-3 overflow-clip px-6 pt-10 pb-32 md:h-screen md:px-10 md:pt-10 md:pb-60"
>
  <h2
    class="place-down relative text-center font-lora text-3xl font-semibold text-saffron text-shadow-md text-shadow-dark-purple/40 md:text-4xl"
  >
    This July we ran a hardware hackathon in Shenzhen, China
  </h2>
  <p class="place-down relative text-center font-lora text-xl text-mint italic">Watch the recap below</p>

  <div class="place-down-stage relative mt-6 flex h-full w-full items-center justify-center gap-10 md:mt-0">
    <div class="place-down z-20 hidden shrink-0 flex-col justify-center gap-40 xl:-mr-8 xl:flex">
      {#each leftPhotos as { src, alt, at, ...card } (src)}
        <PhotoCard {...card} tone="text-saffron">
          <img {src} {alt} loading="lazy" class="size-full object-cover {at ?? ''}" />
          <div class="absolute inset-0 bg-vivid-blue/10"></div>
        </PhotoCard>
      {/each}
    </div>
    <RecapVideo
      id="dTGFOKblRc4"
      title="Shenzhen recap video"
      class="place-down aspect-video w-full max-w-full md:h-[85%] md:w-auto xl:h-auto xl:min-w-0 xl:flex-1"
    />
    <div class="place-down z-20 hidden shrink-0 flex-col justify-between pb-24 xl:-ml-8 xl:flex">
      {#each rightPhotos as { src, alt, at, ...card } (src)}
        <PhotoCard {...card} tone="text-saffron">
          <img {src} {alt} loading="lazy" class="size-full object-cover {at ?? ''}" />
          <div class="absolute inset-0 bg-vivid-blue/10"></div>
        </PhotoCard>
      {/each}
    </div>
  </div>
</section>
