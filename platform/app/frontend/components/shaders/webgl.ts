// The little WebGL2 the landing effects need: compile a shader pair, upload point attributes, set uniforms and
// build the two matrices the vertex shaders read. Each effect is a Layer (particles.ts, shards.ts) drawn by
// LandingScene.svelte; the GLSL lives next to it in .vert/.frag files.

// What every layer is drawn through: the lens, and how far the camera has drifted from centre (world units).
export type View = { projection: Float32Array; camera: readonly number[] }

export type Layer = {
  update(delta: number): void
  draw(view: View): void
  pointerMove(x: number, y: number, aspect: number): void // x and y in clip space, -1 to 1
  pointerLeave(): void
}

type UniformValue = number | Float32Array | readonly [number, number]

export type Points = {
  draw(uniforms: Record<string, UniformValue>): void
}

// One draw call of point sprites. Attributes are per point; `position` (3 floats) is required.
export function createPoints(
  gl: WebGL2RenderingContext,
  vertexShader: string,
  fragmentShader: string,
  attributes: Record<string, { data: Float32Array; size: number }>,
): Points {
  const program = createProgram(gl, vertexShader, fragmentShader)
  const vao = gl.createVertexArray()
  gl.bindVertexArray(vao)
  for (const [name, { data, size }] of Object.entries(attributes)) {
    const location = gl.getAttribLocation(program, name)
    if (location < 0) continue // declared but unused, so the compiler dropped it
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer())
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW)
    gl.enableVertexAttribArray(location)
    gl.vertexAttribPointer(location, size, gl.FLOAT, false, 0, 0)
  }
  gl.bindVertexArray(null)
  const count = attributes.position.data.length / 3

  const locations = new Map<string, WebGLUniformLocation | null>()
  const locate = (name: string) => {
    if (!locations.has(name)) locations.set(name, gl.getUniformLocation(program, name))
    return locations.get(name)!
  }

  return {
    draw(uniforms) {
      gl.useProgram(program)
      for (const [name, value] of Object.entries(uniforms)) {
        const location = locate(name)
        if (typeof value === 'number') gl.uniform1f(location, value)
        else if (value.length === 2) gl.uniform2f(location, value[0], value[1])
        else gl.uniformMatrix4fv(location, false, value)
      }
      gl.bindVertexArray(vao)
      gl.drawArrays(gl.POINTS, 0, count)
      gl.bindVertexArray(null)
    },
  }
}

// The camera: 75 degree vertical field of view, sitting at z = 5 and looking straight down -z. It can drift a
// little in x and y (View.camera) for parallax.
const fov = (75 * Math.PI) / 180
const near = 0.1
const far = 1000
const cameraZ = 5

export function perspective(aspect: number, out: Float32Array = new Float32Array(16)) {
  const f = 1 / Math.tan(fov / 2)
  out.fill(0)
  out[0] = f / aspect
  out[5] = f
  out[10] = -(far + near) / (far - near)
  out[11] = -1
  out[14] = (-2 * far * near) / (far - near)
  return out
}

// Where an object sits as seen by the camera: rotated about x then y around its own origin, then moved to
// `position`. Column-major, as WebGL expects.
export function modelView(
  position: readonly [number, number, number],
  rotationX: number,
  rotationY: number,
  camera: readonly number[],
  out: Float32Array = new Float32Array(16),
) {
  const [cx, sx, cy, sy] = [
    Math.cos(rotationX),
    Math.sin(rotationX),
    Math.cos(rotationY),
    Math.sin(rotationY),
  ]
  out.set([cy, sx * sy, -cx * sy, 0, 0, cx, sx, 0, sy, -sx * cy, cx * cy, 0])
  out[12] = position[0] - camera[0]
  out[13] = position[1] - camera[1]
  out[14] = position[2] - cameraZ
  out[15] = 1
  return out
}

// A spring that eases a 2D value towards a target, picking up speed, coasting and settling with a slight sway
// instead of sliding at a fixed rate. Used for the way the effects and the camera follow the cursor.
export function spring(stiffness: number, damping: number) {
  const value = [0, 0]
  const velocity = [0, 0]
  return {
    value,
    step(target: readonly [number, number], delta: number) {
      const dt = Math.min(delta, 1 / 30) // a long frame would make the spring explode
      for (const i of [0, 1]) {
        velocity[i] += ((target[i] - value[i]) * stiffness - velocity[i] * damping) * dt
        value[i] += velocity[i] * dt
      }
    },
  }
}

// each point fades in over its own random time in this range (seconds) when the page opens, so they appear
// one by one instead of all at once
export const randomFadeIn = () => 0.6 + Math.random() * 1.4

export const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v))

function createProgram(gl: WebGL2RenderingContext, vertexSource: string, fragmentSource: string) {
  const program = gl.createProgram()
  for (const [type, source] of [
    [gl.VERTEX_SHADER, vertexSource],
    [gl.FRAGMENT_SHADER, fragmentSource],
  ] as const) {
    const shader = gl.createShader(type)!
    gl.shaderSource(shader, source)
    gl.compileShader(shader)
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) ?? '')
    gl.attachShader(program, shader)
  }
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) ?? '')
  return program
}
