// Flat white shards, after the asteroid belts on themonolithproject.net: bigger and quicker than the particles,
// solid colour with no lighting, angular outlines with their corners slightly rounded off. They flow down a beam
// from the top right towards the falling character, following the light in the background art.
import { clamp, createPoints, modelView, randomFadeIn, spring, type Layer } from './webgl'
import vertexShader from './shards.vert?raw'
import fragmentShader from './shards.frag?raw'

const count = 90

// world units at z = 0, where the screen is about 12 wide and 7.7 tall
const beamCentre = [2.5, 0.5, 0] as const
const beamDirection = normalize(-0.6, -0.8)
const beamHalfLength = 7 // far enough past both ends of the screen that shards wrap round out of sight
const beamWidth = 1.8 // the spread across the beam; most shards fall within this of the centre line
const beamDepth = 1.4 // the spread towards and away from the camera, so the beam is a tube rather than a sheet
const glowRoom = 2.5 // each point is drawn this many times the shard's size, leaving space round it for the glow

// the cursor turns the whole beam round its middle, just enough that the shards slide past each other by depth.
// The beam also follows only part of the camera's drift, so it barely shifts under the cursor.
const maxYaw = 0.012 // radians at the left and right edges of the screen
const maxPitch = 0.008 // radians at the top and bottom
const cameraFollow = 0.3 // share of the camera's drift the beam moves with

export function createShards(gl: WebGL2RenderingContext): Layer {
  // x is how far along the beam, y how far across it, z how far towards the camera
  const positions = new Float32Array(count * 3)
  const sizes = new Float32Array(count)
  const shapes = new Float32Array(count)
  const rotations = new Float32Array(count)
  const spins = new Float32Array(count)
  const fadeIns = new Float32Array(count)

  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() * 2 - 1) * beamHalfLength
    positions[i * 3 + 1] = gaussian() * beamWidth
    positions[i * 3 + 2] = gaussian() * beamDepth
    sizes[i] = 0.3 + Math.random() * 0.2
    shapes[i] = Math.random()
    rotations[i] = Math.random() * Math.PI * 2
    spins[i] = (Math.random() - 0.5) * 0.8
    fadeIns[i] = randomFadeIn()
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
  const mouseTarget: [number, number] = [0, 0]
  let onPage = false
  const turn = spring(4, 3.4) // damping a little under critical (2 * sqrt(stiffness)) so it settles with a sway
  const matrix = new Float32Array(16)
  const camera = [0, 0]

  return {
    update(delta) {
      time += delta
      turn.step(onPage ? mouseTarget : [0, 0], delta)
    },

    draw(view) {
      const [x, y] = turn.value
      camera[0] = view.camera[0] * cameraFollow
      camera[1] = view.camera[1] * cameraFollow
      modelView(beamCentre, -y * maxPitch, x * maxYaw, camera, matrix)

      gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
      points.draw({
        projectionMatrix: view.projection,
        modelViewMatrix: matrix,
        uTime: time,
        uBeamDirection: beamDirection,
        uBeamHalfLength: beamHalfLength,
        uBeamWidth: beamWidth,
        uBeamDepth: beamDepth,
        uGlowRoom: glowRoom,
      })
    },

    pointerMove(x, y) {
      mouseTarget[0] = clamp(x, -1, 1)
      mouseTarget[1] = clamp(y, -1, 1)
      onPage = true
    },

    pointerLeave() {
      onPage = false
    },
  }
}

// a normal distribution, so shards bunch at the middle of the beam and thin out smoothly to either side
function gaussian() {
  return Math.sqrt(-2 * Math.log(1 - Math.random())) * Math.cos(2 * Math.PI * Math.random())
}

function normalize(x: number, y: number) {
  const length = Math.hypot(x, y)
  return [x / length, y / length] as const
}
