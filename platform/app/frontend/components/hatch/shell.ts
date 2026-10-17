// Where the egg breaks, in the egg drawings' units (550 x 736). The crack runs across the shell in uneven steps,
// like the cracks already drawn on the eggs, and is nudged differently every time so no two hatches look the
// same. It opens from MID outwards; the seam is where the bottom half splits when it opens.

export type Point = [number, number]
export const W = 550
export const H = 736

const CRACK: Point[] = [
  [-10, 322],
  [38, 334],
  [70, 296],
  [96, 318],
  [128, 350],
  [150, 326],
  [171, 333],
  [198, 288],
  [232, 344],
  [262, 330],
  [281, 301],
  [302, 316],
  [334, 366],
  [352, 342],
  [379, 348],
  [404, 300],
  [421, 318],
  [452, 352],
  [478, 330],
  [507, 306],
  [560, 338],
]
const MID = 10

// Little cracks off the main one, as steps from a point on it, shown on the tap they belong to.
const BRANCHES: { from: number; steps: Point[]; at: number }[] = [
  {
    from: 7,
    steps: [
      [-10, -34],
      [16, -22],
      [-6, -18],
    ],
    at: 2,
  },
  {
    from: 15,
    steps: [
      [12, -40],
      [-14, -20],
    ],
    at: 2,
  },
  {
    from: 4,
    steps: [
      [8, 44],
      [-16, 30],
    ],
    at: 3,
  },
  {
    from: 17,
    steps: [
      [-6, 38],
      [18, 26],
      [-4, 16],
    ],
    at: 3,
  },
  { from: 12, steps: [[-4, 30]], at: 3 },
]

const between = (min: number, max: number) => min + Math.random() * (max - min)
const pct = ([x, y]: Point) => `${(x / W) * 100}% ${(y / H) * 100}%`
const line = (points: Point[]) => 'M' + points.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L')
const polygon = (points: string[]) => `polygon(${points.join(', ')})`
const reversed = <T>(list: T[]) => [...list].reverse()

export function breakShell() {
  const last = CRACK.length - 1
  const crack: Point[] = CRACK.map(([x, y], i) =>
    i === 0 || i === last ? [x, y] : [x + between(-7, 7), y + between(-12, 12)],
  )
  const [mx] = crack[MID]
  const seam: Point[] = [
    [mx + between(-30, -10), between(430, 460)],
    [mx + between(5, 30), between(530, 570)],
    [mx + between(-25, -5), between(630, 670)],
    [mx + between(-5, 15), 760],
  ]
  const branches = BRANCHES.map(({ from, steps, at }) => {
    const points: Point[] = [crack[from]]
    for (const [dx, dy] of steps) {
      const [x, y] = points[points.length - 1]
      points.push([x + dx * between(0.7, 1.3), y + dy * between(0.8, 1.2)])
    }
    return { d: line(points), at }
  })
  return {
    crack,
    // Drawn from the middle out to each side.
    paths: [line(reversed(crack.slice(0, MID + 1))), line(crack.slice(MID))],
    branches,
    pieces: [
      polygon(['-10% -10%', '110% -10%', ...reversed(crack).map(pct)]),
      polygon([...crack.slice(0, MID + 1).map(pct), ...seam.map(pct), '-10% 110%']),
      polygon([...crack.slice(MID).map(pct), '110% 110%', ...reversed(seam).map(pct)]),
    ],
  }
}
