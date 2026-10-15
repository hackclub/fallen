<script lang="ts">
  // The landing page's recap video, over the page's backdrop (Landing/Index.svelte). A parchment heading and
  // periwinkle subtitle, with gold framing the video.
  import RecapVideo from '@/components/RecapVideo.svelte'
</script>

<section
  id="watch"
  class="place-down-stage relative flex flex-col items-center gap-3 overflow-clip px-6 py-10 md:h-screen md:p-10"
>
  <h2
    class="place-down relative text-center font-lora text-3xl font-bold text-light-blue text-shadow-md text-shadow-dark-purple/40 md:text-4xl"
  >
    Last July we brought 180+ to Shenzhen, China
  </h2>
  <p class="place-down relative text-center font-lora text-xl text-blue italic">Watch the recap below</p>

  <div class="place-down-stage relative mt-6 flex h-full w-full items-center justify-center md:mt-0">
    <RecapVideo
      id="dTGFOKblRc4"
      title="Shenzhen recap video"
      class="place-down aspect-video w-full max-w-full overflow-hidden md:h-[80%] md:w-auto"
    />
  </div>
</section>
