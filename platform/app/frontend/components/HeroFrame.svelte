<!-- The landing hero's frame: a gold hairline with a fainter one inside it, and a star on each corner. Goes inside a
     positioned element; m-0 so a parent's space-y can't shift it. -->

<div class="pointer-events-none absolute inset-6 z-3 m-0 md:inset-10" aria-hidden="true">
  <div class="absolute inset-0 border border-[#e8b866]/55"></div>
  <!-- <div class="absolute inset-1.5 border border-[#e8b866]/20"></div> -->
  {#each ['top-0 left-0', 'top-0 left-full', 'top-full left-0', 'top-full left-full'] as corner (corner)}
    <!-- assets/star.svg, inlined so it takes the gold -->
    <svg
      viewBox="0 0 96 95"
      class="absolute {corner} size-14 -translate-x-[46.875%] -translate-y-[51.58%] text-[#e8b866]"
      fill="none"
    >
      <path
        d="M45 21.6c0 5.6.1 10 .6 13.5.7 4.1 2 7.1 4.8 9.4 2.8 2.3 6.3 3.4 11.1 3.9 4.8.6 11 .6 19.2.6l-5.8 0c-5.4 0-9.8.1-13.4.5-4.8.6-8.4 1.6-11.1 3.9-2.8 2.3-4.1 5.3-4.8 9.4-.7 4-.6 9.2-.6 16l0-2.5c0-5.6-.1-10-.6-13.5-.7-4.1-2-7.1-4.8-9.4-2.8-2.3-6.3-3.4-11.1-3.9-4.8-.5-11-.5-19.2-.5l5.8 0c5.4 0 9.8-.1 13.4-.5 4.8-.5 8.4-1.6 11.1-3.9 2.8-2.3 4.1-5.3 4.8-9.4.7-4 .6-9.2.6-16z"
        stroke="currentColor"
        stroke-width="2"
      />
    </svg>
  {/each}
</div>
