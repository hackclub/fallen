// Numbers an element's children (--i) for the `stagger-in` utility, which fades them in one after another.
export function stagger(el: HTMLElement) {
  for (const [i, child] of [...el.children].entries())
    (child as HTMLElement).style.setProperty('--i', String(i))
}
