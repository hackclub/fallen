<script lang="ts">
  import * as THREE from 'three'
  import { T, useTask, useThrelte } from '@threlte/core'

  const axis = 80

  const positions = new Float32Array(axis * axis * 3) // storing points' positions

  const sizes = new Float32Array(axis * axis) //defining the size of the array

  const shapes = new Float32Array(axis * axis)

  const rotations = new Float32Array(axis * axis) // starting angle per particle

  const spins = new Float32Array(axis * axis) // spin speed per particle, either direction

  const { canvas } = useThrelte()

  const uniforms = {
    uTime: { value: 0 },
    uMouse: { value: new THREE.Vector2() }, // in clip space, trails behind the real cursor
    uHover: { value: 0 }, // fades the glow in and out as the cursor enters and leaves
    uAspect: { value: 1 },
  }

  const mouseTarget = new THREE.Vector2()
  const glowHold = 0.8 // seconds the glow stays after the cursor stops before it fades
  let idle = Infinity // seconds since the cursor last moved
  let onPage = false

  // the whole field tilts and drifts towards the cursor as one sheet, easing back to centre when it leaves
  let field = $state<THREE.Group>()
  const tilt = new THREE.Vector2()
  const tiltVelocity = new THREE.Vector2()
  const tiltTarget = new THREE.Vector2()
  const maxTilt = 0.06 // radians at the edge of the screen
  const maxShift = 0.08 // world units at the edge of the screen
  const stiffness = 5 // how hard the spring pulls towards the cursor
  const damping = 3.6 // a little under critical (2 * sqrt(stiffness)) so it settles with a slight sway

  // eases off towards the screen edges so most of the movement happens near the middle
  const shape = (v: number) => Math.sin((THREE.MathUtils.clamp(v, -1, 1) * Math.PI) / 2)

  useTask((delta) => {
    uniforms.uTime.value += delta
    idle += delta

    // ease towards the cursor so the glow lags behind it; higher = snappier
    uniforms.uMouse.value.lerp(mouseTarget, 1 - Math.exp(-delta * 2))

    const hoverTarget = onPage && idle < glowHold ? 1 : 0
    uniforms.uHover.value += (hoverTarget - uniforms.uHover.value) * (1 - Math.exp(-delta * 1.5))

    // a spring rather than a lerp so the field picks up speed, coasts and settles instead of sliding at a fixed rate
    if (onPage) tiltTarget.set(shape(mouseTarget.x), shape(mouseTarget.y))
    else tiltTarget.set(0, 0)
    const dt = Math.min(delta, 1 / 30) // a long frame would make the spring explode
    tiltVelocity.x += ((tiltTarget.x - tilt.x) * stiffness - tiltVelocity.x * damping) * dt
    tiltVelocity.y += ((tiltTarget.y - tilt.y) * stiffness - tiltVelocity.y * damping) * dt
    tilt.addScaledVector(tiltVelocity, dt)
    if (field) {
      field.rotation.x = -tilt.y * maxTilt
      field.rotation.y = tilt.x * maxTilt
      field.position.x = tilt.x * maxShift
      field.position.y = tilt.y * maxShift
    }
  })

  // the canvas ignores pointer events so the page stays clickable, so track the mouse on the window
  function onPointerMove(event: PointerEvent) {
    const rect = canvas.getBoundingClientRect()
    mouseTarget.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    )
    uniforms.uAspect.value = rect.width / rect.height

    // start the glow where the cursor is rather than sliding over from where it last faded
    if (uniforms.uHover.value < 0.01) uniforms.uMouse.value.copy(mouseTarget)
    idle = 0
    onPage = true
  }

  function onPointerLeave() {
    onPage = false
  }

  let i = 0

  for (let x = 0; x < axis; x++) {
    for (let y = 0; y < axis; y++) {
      positions[i * 3] = (x - axis / 2) * 0.08 * (Math.random() - 0.5) * 40 // split points, half on the negative side, half positive. 0.12 spacing
      positions[i * 3 + 1] = (y - axis / 2) * 0.12 * (Math.random() - 0.5) * 40

      sizes[i] = 0.04 + Math.random() * 0.4
      shapes[i] = Math.random()
      rotations[i] = Math.random() * Math.PI * 2
      spins[i] = (Math.random() - 0.5) * 0.6

      i++
    }
  }

  const geometry = new THREE.BufferGeometry()

  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))

  geometry.setAttribute('sizes', new THREE.BufferAttribute(sizes, 1))

  geometry.setAttribute('shapes', new THREE.BufferAttribute(shapes, 1))

  geometry.setAttribute('rotations', new THREE.BufferAttribute(rotations, 1))

  geometry.setAttribute('spins', new THREE.BufferAttribute(spins, 1))
</script>

<svelte:window onpointermove={onPointerMove} />
<svelte:document onmouseleave={onPointerLeave} />

<T.Group bind:ref={field}>
  <T.Points {geometry}>
    <T.ShaderMaterial
      {uniforms}
      transparent
      depthWrite={false}
      blending={THREE.AdditiveBlending}
      vertexShader={`
          attribute float sizes;
          attribute float shapes;
          attribute float rotations;
          attribute float spins;

          uniform float uTime;
          uniform vec2 uMouse;
          uniform float uHover;
          uniform float uAspect;

          varying float vSeed;
          varying float vAngle;
          varying float vTumble;
          varying float vDiffuse;
          varying float vHover;

          void main() {
            vec3 p = position;

            vSeed = shapes;

            vAngle = rotations + uTime * spins;
            // each shape flips around its own in-plane axis while it spins
            float flip = uTime * spins * 0.8 + rotations;
            vTumble = 0.35 + 0.65 * abs(cos(flip));

            // the shape's surface normal in 3D, from its spin and flip
            vec2 flipAxis = vec2(cos(vAngle), sin(vAngle));
            vec3 normal = vec3(flipAxis * sin(flip), cos(flip));

            // light from the top right; flat shapes reflect off both faces
            vec3 lightDir = normalize(vec3(0.5, 0.6, 0.7));
            vDiffuse = abs(dot(normal, lightDir));

            float speed = 0.04 + shapes * 0.05;

            p.x += mod(position.x + 6.0 - uTime * speed + 12.0, 12.0) - 6.0;
            p.y += mod(position.y + 4.0 - uTime * speed * 0.7 + 8.0, 8.0) - 4.0;

            vec4 mvPosition = modelViewMatrix * vec4(p, 1.0);

            gl_Position = projectionMatrix * mvPosition;

            gl_PointSize = sizes * (300.0 / max(1.0, -mvPosition.z));

            // brighten a little near the cursor
            vec2 toMouse = gl_Position.xy / gl_Position.w - uMouse;
            toMouse.x *= uAspect;
            vHover = (1.0 - smoothstep(0.1, 0.45, length(toMouse))) * uHover;
          }
        `}
      fragmentShader={`
            varying float vSeed;
            varying float vAngle;
            varying float vTumble;
            varying float vDiffuse;
            varying float vHover;

            float hash(float n) {
                return fract(sin(n) * 43758.5453);
            }

            // max() that blends the two shapes over a width of k instead of meeting at a sharp corner
            float smax(float a, float b, float k) {
                if (k <= 0.0) return max(a, b);
                float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
                return mix(a, b, h) + k * h * (1.0 - h);
            }

            void main() {
                vec2 uv = gl_PointCoord - vec2(0.5);

                float c = cos(vAngle);
                float s = sin(vAngle);
                uv = mat2(c, -s, s, c) * uv;
                uv.x /= vTumble;

                float h1 = hash(vSeed * 91.7);
                float h3 = hash(vSeed * 13.1 + 2.0);

                // irregular convex polygon: 4-6 edges at jittered angles and distances.
                // some edges bulge into curves and some corners melt smoothly into the next edge
                float sides = 4.0 + floor(h1 * 3.0);
                float rounding = mix(0.01, 0.03, h3);
                float d = -1.0;
                for (int i = 0; i < 6; i++) {
                    if (float(i) >= sides) break;
                    float fi = float(i);
                    float a = (fi + (hash(vSeed * 17.0 + fi) - 0.5) * 0.3) * 6.2831853 / sides;
                    float h = mix(0.13, 0.22, hash(vSeed * 29.0 + fi * 3.7)) - rounding;
                    vec2 n = vec2(cos(a), sin(a));

                    float edge = dot(uv, n) - h;
                    if (hash(vSeed * 53.0 + fi * 5.1) > 0.5) {
                        // curved edge: a circle tangent to where the straight edge would be, so it never pokes past it
                        float r = mix(0.25, 0.6, hash(vSeed * 61.0 + fi * 2.3));
                        edge = length(uv + n * (r - h)) - r;
                    }

                    float k = hash(vSeed * 71.0 + fi * 4.1) > 0.6 ? 0.12 : 0.0;
                    d = smax(d, edge, k);
                }
                d -= rounding;

                float alpha = 1.0 - smoothstep(-0.006, 0.006, d);

                float white = vHover;

                // soft glow spilling past the edge while hovered
                float halo = exp(-max(d, 0.0) * 30.0) * white * (1.0 - alpha) * 0.05;

                if (alpha < 0.01 && halo < 0.01) discard;

                // light catching the edges
                float rim = smoothstep(-0.05, 0.0, d);

                vec3 colorA = vec3(1.0, 0.88, 0.82);
                vec3 colorB = vec3(0.96, 0.78, 0.84);
                vec3 colorC = vec3(0.85, 0.86, 1.0);

                vec3 color = mix(colorA, colorB, vSeed);
                color = mix(color, colorC, smoothstep(0.75, 1.0, vSeed));

                // a rare few are green (#C7E1B8)
                if (hash(vSeed * 37.3 + 5.0) > 0.93) color = vec3(0.78, 0.882, 0.722);

                vec3 light = mix(color, vec3(1.0), white * 0.4);
                // faint when facing away from the light, only a little brighter under the cursor
                float lit = 0.05 + 0.12 * vDiffuse + 0.05 * rim * vDiffuse;
                float intensity = alpha * mix(lit, 0.25, white) + halo;

                // additive blending multiplies rgb by alpha, so alpha is how much light gets added
                gl_FragColor = vec4(light, clamp(intensity, 0.0, 1.0));
            }
        `}
    ></T.ShaderMaterial>
  </T.Points>
</T.Group>
