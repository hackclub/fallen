// Every measurement in the dialog is a "design unit": one px in the Figma
// frame (1185 x 541). The stage sets `--dlg-u` to the px size of one unit
// from its own width and height, so the whole composition bubble, text,
// avatar, choices scales as one fixed-aspect picture instead of reflowing.
export const SCENE = { width: 1185, height: 541 }

export const BUBBLE = { left: 211, top: 267, width: 974, height: 201, fill: '#2B271F' }

export const NAME_TAG = {
  left: 57, // relative to the bubble
  top: -39,
  minWidth: 187,
  height: 63,
  paddingX: 40,
  paddingTop: 8,
  radius: 100,
  fontSize: 36,
  lineHeight: 1.2,
  fill: '#FF427D',
}

// The slides set body copy in a 688-wide box centred on the bubble. Copy that
// would run to a third line steps the type down towards `minFontSize` rather
// than the box growing wider.
export const BODY_TEXT = { fontSize: 40, minFontSize: 32, fontStep: 1, lineHeight: 1.3, width: 688 }

// The Figma arrow is a 31.93 x 22.25 vector rotated -88.64°, whose bounding
// box is 23 x 32.45. Positions are relative to the bubble.
export const ARROW = {
  right: 50,
  bottom: 29.6,
  width: 23,
  height: 32.45,
  pathWidth: 31.9327,
  pathHeight: 22.2504,
  rotate: -88.64,
  fill: '#FFFFFF',
}

export const CHOICES = {
  right: 63.6, // relative to the scene
  bottom: 246.3,
  maxWidth: 600, // the card hugs its longest label up to this
  minWidth: 285,
  radius: 16,
  rotate: 1.41,
  fill: '#38342C',
  itemPaddingX: 33,
  itemPaddingY: 15,
  fontSize: 28,
  lineHeight: 1.2,
  divider: 'rgba(255, 255, 255, 0.6)',
  highlight: 'rgba(255, 255, 255, 0.14)',
}

export const POPUP = {
  width: 640,
  radius: 28,
  padding: 44,
  titleSize: 38,
  bodySize: 26,
  buttonSize: 28,
  fill: '#38342C',
  accent: '#FF427D',
}

// Phones and short windows. Scaled as one picture the copy would shrink to a
// few px, so once a unit would be smaller than `belowUnit` the stage stacks the
// same pieces instead (DialogStage): the character standing on a full-width
// bubble, the choices beside it. Each piece keeps its design-unit sizes and
// gets its own unit in px, so it stays readable and thumb-sized. `inset` and
// `maxWidth` are px; `wobble` is px per wobble-canvas unit (wobble.ts).
export const COMPACT = {
  belowUnit: 0.5,
  inset: 12,
  maxWidth: 560,
  stage: 0.5,
  character: 0.34,
  text: 0.5,
  nameTag: 0.5,
  choices: 0.64,
  arrow: 0.6,
  bubblePadding: { x: 36, y: 22 },
  bubbleMinHeight: 116,
  // How far the character's feet come down over the bubble, and the gap
  // between the name tag and the character, in px.
  overlap: 34,
  tagGap: 4,
  wobble: 0.4,
}

// Outside a DialogStage the variable is unset and one unit is one px, so the
// game-styled pieces (GameButton, StripPanel) render at design size anywhere.
export const u = (n: number) => `calc(var(--dlg-u, 1px) * ${n})`
