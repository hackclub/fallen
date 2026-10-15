// A field of small faint polygons drifting up and to the left, lit from the top right. They glow under the
// cursor, and the whole field tilts and drifts towards it as one sheet, easing back to centre when it leaves.
import { clamp, createPoints, modelView, randomFadeIn, spring, type Layer } from './webgl'
import vertexShader from './particles.vert?raw'
import fragmentShader from './particles.frag?raw'

const glowHold = 0.8 // seconds the glow stays after the cursor stops before it fades
const maxTilt = 0.06 // radians at the edge of the screen
const maxShift = 0.08 // world units at the edge of the screen

// eases off towards the screen edges so most of the movement happens near the middle
const shape = (v: number) => Math.sin((clamp(v, -1, 1) * Math.PI) / 2)

// axis: the field starts as an axis x axis grid, scattered. brightness scales how much light each particle adds.
export function createParticles(gl: WebGL2RenderingContext, { axis = 80, brightness = 1 } = {}): Layer {
  const count = axis * axis
  const positions = new Float32Array(count * 3)
  const sizes = new Float32Array(count)
  const shapes = new Float32Array(count)
  const rotations = new Float32Array(count) // starting angle
  const spins = new Float32Array(count) // spin speed, either direction
  const fadeIns = new Float32Array(count)

  let i = 0
  for (let x = 0; x < axis; x++) {
    for (let y = 0; y < axis; y++) {
      positions[i * 3] = (x - axis / 2) * 0.08 * (Math.random() - 0.5) * 40
      positions[i * 3 + 1] = (y - axis / 2) * 0.12 * (Math.random() - 0.5) * 40
      sizes[i] = 0.04 + Math.random() * 0.4
      shapes[i] = Math.random()
      rotations[i] = Math.random() * Math.PI * 2
      spins[i] = (Math.random() - 0.5) * 0.6
      fadeIns[i] = randomFadeIn()
      i++
    }
  }

  const points = createPoints(gl, vertexShader, fragmentShader, {
    position: { data: positions, size: 3 },
    sizes: { data: sizes, size: 1 },
    shapes: { data: shapes, size: 1 },
    rotations: { data: rotations, size: 1 },
    spins: { data: spins, size: 1 },
    fadeIns: { data: fadeIns, size: 1 },
  })

  let time = 0
  const mouse: [number, number] = [0, 0] // trails behind the real cursor
  const mouseTarget: [number, number] = [0, 0]
  let hover = 0 // fades the glow in and out as the cursor enters and leaves
  let aspect = 1
  let idle = Infinity // seconds since the cursor last moved
  let onPage = false
  const tilt = spring(5, 3.6) // damping a little under critical (2 * sqrt(stiffness)) so it settles with a sway
  const matrix = new Float32Array(16)

  return {
    update(delta) {
      time += delta
      idle += delta

      // ease towards the cursor so the glow lags behind it; higher = snappier
      const follow = 1 - Math.exp(-delta * 2)
      mouse[0] += (mouseTarget[0] - mouse[0]) * follow
      mouse[1] += (mouseTarget[1] - mouse[1]) * follow

      const hoverTarget = onPage && idle < glowHold ? 1 : 0
      hover += (hoverTarget - hover) * (1 - Math.exp(-delta * 1.5))

      tilt.step(onPage ? [shape(mouseTarget[0]), shape(mouseTarget[1])] : [0, 0], delta)
    },

    draw(view) {
      const [x, y] = tilt.value
      modelView([x * maxShift, y * maxShift, 0], -y * maxTilt, x * maxTilt, view.camera, matrix)

      // additive, so overlapping particles add up to brighter light
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE)
      points.draw({
        projectionMatrix: view.projection,
        modelViewMatrix: matrix,
        uTime: time,
        uMouse: mouse,
        uHover: hover,
        uAspect: aspect,
        uBrightness: brightness,
      })
    },

    pointerMove(x, y, pointerAspect) {
      mouseTarget[0] = x
      mouseTarget[1] = y
      aspect = pointerAspect
      // start the glow where the cursor is rather than sliding over from where it last faded
      if (hover < 0.01) [mouse[0], mouse[1]] = [x, y]
      idle = 0
      onPage = true
    },

    pointerLeave() {
      onPage = false
    },
  }
}
