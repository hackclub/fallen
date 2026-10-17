// Moves a `glimmer` label's light to the pointer: sets where it is, in px from the link's top left.
export function followPointer(event: PointerEvent) {
  const link = event.currentTarget as HTMLElement
  const box = link.getBoundingClientRect()
  link.style.setProperty('--glimmer-x', `${event.clientX - box.left}px`)
  link.style.setProperty('--glimmer-y', `${event.clientY - box.top}px`)
}
