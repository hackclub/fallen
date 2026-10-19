// Numbers an element's children (--i) for the `stagger-in` utility, which fades them in one after another. A child
// that has arrived is marked, so the fade comes off it: otherwise a hover animation (`tile`) replacing it would play
// the fade again when the pointer leaves.
export function stagger(el: HTMLElement) {
  for (const [i, child] of [...el.children].entries())
    (child as HTMLElement).style.setProperty('--i', String(i))

  const arrived = (event: AnimationEvent) => {
    if (
      event.animationName === 'stagger-in' &&
      event.target instanceof HTMLElement &&
      event.target.parentElement === el
    )
      event.target.dataset.staggered = ''
  }
  el.addEventListener('animationend', arrived)
  return () => el.removeEventListener('animationend', arrived)
}
