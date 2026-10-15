<script lang="ts">
  let { text }: { text: string } = $props()
</script>

<span class="group relative inline-flex">
  <button
    type="button"
    tabindex="0"
    aria-label={text}
    class="flex h-4 w-4 cursor-help items-center justify-center rounded-full bg-ink/15 font-outfit text-[10px] leading-none text-ink-soft"
  >
    ?
  </button>
  <span
    role="tooltip"
    class="pointer-events-none invisible absolute top-1/2 left-full z-10 ml-2 w-max max-w-52 -translate-y-1/2 rounded-md bg-ink px-2.5 py-1.5 text-center font-outfit text-xs text-paper opacity-0 transition group-focus-within:visible group-focus-within:opacity-100 group-hover:visible group-hover:opacity-100"
  >
    {text}
  </span>
</span>
