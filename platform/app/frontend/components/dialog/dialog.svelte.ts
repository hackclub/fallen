import type { Character, DialogContext, DialogNode, DialogPhase, DialogScript, DialogVars } from './types'

type Options = {
  characters: Character[]
  vars?: DialogVars
  onComplete?: () => void
}

type State = {
  nodeId: string
  phase: DialogPhase
  // Bumped on every node change so the text reveal restarts even when two consecutive nodes have identical text.
  revealKey: number
  skipped: boolean
  speakerId: string | undefined
  history: string[]
}

function interpolate(text: string, vars: DialogVars) {
  return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, key: string) => String(vars[key] ?? ''))
}

function entryPhase(node: DialogNode | undefined): DialogPhase {
  return node?.text ? 'revealing' : node?.popup ? 'popup' : 'idle'
}

export class Dialog {
  vars: DialogVars = $state({})
  state: State = $state()!

  private nodes: Map<string, DialogNode>
  private characters: Map<string, Character>

  constructor(
    private script: DialogScript,
    private options: Options,
  ) {
    this.nodes = new Map(script.nodes.map((node) => [node.id, node]))
    this.characters = new Map(options.characters.map((c) => [c.id, c]))
    this.vars = { ...options.vars }
    const start = this.nodes.get(script.start)
    this.state = {
      nodeId: script.start,
      phase: entryPhase(start),
      revealKey: 0,
      skipped: false,
      speakerId: start?.speaker,
      history: [script.start],
    }
  }

  node: DialogNode = $derived.by(() => {
    const node = this.nodes.get(this.state.nodeId)
    if (!node) throw new Error(`Dialog node "${this.state.nodeId}" does not exist`)
    return node
  })

  ctx: DialogContext = $derived({
    vars: this.vars,
    setVar: (key, value) => (this.vars = { ...this.vars, [key]: value }),
    history: this.state.history,
  })

  character = $derived.by(() =>
    this.state.speakerId ? this.characters.get(this.state.speakerId) : undefined,
  )
  emotion = $derived(this.node.emotion)
  phase = $derived(this.state.phase)
  revealKey = $derived(this.state.revealKey)
  skipped = $derived(this.state.skipped)

  text = $derived.by(() => {
    const node = this.node
    if (!node.text) return ''
    const raw = typeof node.text === 'function' ? node.text(this.ctx) : node.text
    return interpolate(raw, this.vars)
  })

  finishReveal = () => {
    if (this.state.phase === 'revealing') this.state.phase = 'idle'
  }

  // Click / Enter. While words are still appearing the first press only completes the line (the Animal Crossing
  // rule) and a node with choices waits for one to be picked.
  advance = () => {
    if (this.state.phase === 'revealing') {
      this.state = { ...this.state, phase: 'idle', skipped: true }
      return
    }
    if (this.state.phase !== 'idle') return
    const node = this.node
    if (node.choices?.length || node.panel) return
    if (node.popup) {
      this.state.phase = 'popup'
      return
    }
    this.goTo(this.resolveNext(node.next))
  }

  choose = (index: number) => {
    if (this.state.phase !== 'idle') return
    const choice = this.node.choices?.[index]
    if (!choice) return
    choice.onSelect?.(this.ctx)
    this.goTo(choice.next ?? this.resolveNext(this.node.next))
  }

  // For panels: continue to `target`, or to the node's own `next`.
  go = (target?: string) => {
    if (this.state.phase !== 'idle') return
    this.goTo(target ?? this.resolveNext(this.node.next))
  }

  closePopup = () => {
    if (this.state.phase !== 'popup') return
    this.goTo(this.resolveNext(this.node.next))
  }

  restart = () => {
    this.vars = { ...this.options.vars }
    const first = this.nodes.get(this.script.start)
    this.state = {
      nodeId: this.script.start,
      phase: entryPhase(first),
      revealKey: this.state.revealKey + 1,
      skipped: false,
      speakerId: first?.speaker,
      history: [this.script.start],
    }
  }

  private goTo(target: string | undefined) {
    if (target === undefined) {
      this.state.phase = 'done'
      this.options.onComplete?.()
      return
    }
    const next = this.nodes.get(target)
    if (!next) throw new Error(`Dialog node "${target}" does not exist`)
    this.state = {
      nodeId: target,
      phase: entryPhase(next),
      revealKey: this.state.revealKey + 1,
      skipped: false,
      speakerId: next.speaker ?? this.state.speakerId,
      history: [...this.state.history, target],
    }
  }

  private resolveNext(next: DialogNode['next']) {
    return typeof next === 'function' ? next(this.ctx) : next
  }
}
