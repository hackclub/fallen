<script lang="ts">
  // The landing page's footer, over the end of the page's gradient down to black (Landing/Index.svelte). It never
  // rises far up the screen, so its entrance lands just before it's fully in view.
  import OrnamentNav from '@/components/OrnamentNav.svelte'
  import Wordmark from '@/components/Wordmark.svelte'

  const links = [
    { label: 'Hack Club', href: 'https://hackclub.com' },
    { label: 'Privacy Policy', href: 'https://hackclub.com/privacy-and-terms' },
    { label: 'Fulfillment Bounty', href: 'https://forms.hackclub.com/bounty' },
  ]
</script>

<footer
  id="footer"
  class="place-down-stage relative flex flex-col items-center justify-center gap-16 overflow-clip px-6 py-20 text-center md:min-h-140 md:px-10 [--place-down-range:entry_0%_entry_70%]"
>
  <OrnamentNav items={links} small glow label="Footer" class="place-down-stage" itemClass="place-down" />
  <Wordmark
    onDark
    class="place-down h-24 md:absolute md:right-18 md:bottom-14 md:h-36 [filter:drop-shadow(0_0_6px_rgb(255_255_255/0.7))_drop-shadow(0_0_24px_rgb(255_255_255/0.35))]"
  />
</footer>
