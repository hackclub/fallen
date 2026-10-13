<script lang="ts">
  // flat white shards, after the asteroid belts on themonolithproject.net: bigger and quicker than the
  // particles, solid colour with no lighting, angular outlines with their corners slightly rounded off
  import * as THREE from 'three'
  import { T, useTask, useThrelte } from '@threlte/core'

  const count = 90

  // the shards flow down a beam from the top right towards the falling character, following the light in the
  // background art. world units at z = 0, where the screen is about 12 wide and 7.7 tall
  const beamCentre = new THREE.Vector2(2.5, 0.5)
  const beamDirection = new THREE.Vector2(-0.6, -0.8).normalize()
  const beamHalfLength = 7 // far enough past both ends of the screen that shards wrap round out of sight
  const beamWidth = 1.8 // the spread across the beam; most shards fall within this of the centre line
  const beamDepth = 1.4 // the spread towards and away from the camera, so the beam is a tube rather than a sheet

  // a normal distribution, so shards bunch at the middle of the beam and thin out smoothly to either side
  function gaussian() {
    return Math.sqrt(-2 * Math.log(1 - Math.random())) * Math.cos(2 * Math.PI * Math.random())
  }

  // x is how far along the beam, y how far across it, z how far towards the camera
  const positions = new Float32Array(count * 3)
  const sizes = new Float32Array(count)
  const shapes = new Float32Array(count)
  const rotations = new Float32Array(count)
  const spins = new Float32Array(count)

  for (let i = 0; i < count; i++) {
    positions[i * 3] = (Math.random() * 2 - 1) * beamHalfLength
    positions[i * 3 + 1] = gaussian() * beamWidth
    positions[i * 3 + 2] = gaussian() * beamDepth

    sizes[i] = 0.3 + Math.random() * 0.2
    shapes[i] = Math.random()
    rotations[i] = Math.random() * Math.PI * 2
    spins[i] = (Math.random() - 0.5) * 0.8
  }

  const geometry = new THREE.BufferGeometry()
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
  geometry.setAttribute('sizes', new THREE.BufferAttribute(sizes, 1))
  geometry.setAttribute('shapes', new THREE.BufferAttribute(shapes, 1))
  geometry.setAttribute('rotations', new THREE.BufferAttribute(rotations, 1))
  geometry.setAttribute('spins', new THREE.BufferAttribute(spins, 1))

  const uniforms = {
    uTime: { value: 0 },
    uBeamDirection: { value: beamDirection },
    uBeamHalfLength: { value: beamHalfLength },
    uBeamWidth: { value: beamWidth },
    uBeamDepth: { value: beamDepth },
    uGlowRoom: { value: 2.5 }, // each point is drawn this many times the shard's size, leaving space round it for the glow
  }

  // the cursor turns the whole beam round its middle, much further than the particles tilt, so one end swings
  // towards the camera and the shards slide past each other by depth
  const { canvas } = useThrelte()
  let beam = $state<THREE.Group>()
  const mouseTarget = new THREE.Vector2()
  let onPage = false
  const turn = new THREE.Vector2()
  const turnVelocity = new THREE.Vector2()
  const turnTarget = new THREE.Vector2()
  const maxYaw = 0.04 // radians at the left and right edges of the screen
  const maxPitch = 0.025 // radians at the top and bottom
  const stiffness = 4
  const damping = 3.4 // a little under critical (2 * sqrt(stiffness)) so it settles with a slight sway

  useTask((delta) => {
    uniforms.uTime.value += delta

    if (onPage) turnTarget.copy(mouseTarget)
    else turnTarget.set(0, 0)
    const dt = Math.min(delta, 1 / 30) // a long frame would make the spring explode
    turnVelocity.x += ((turnTarget.x - turn.x) * stiffness - turnVelocity.x * damping) * dt
    turnVelocity.y += ((turnTarget.y - turn.y) * stiffness - turnVelocity.y * damping) * dt
    turn.addScaledVector(turnVelocity, dt)
    if (beam) {
      beam.rotation.y = turn.x * maxYaw
      beam.rotation.x = -turn.y * maxPitch
    }
  })

  // the canvas ignores pointer events so the page stays clickable, so track the mouse on the window
  function onPointerMove(event: PointerEvent) {
    const rect = canvas.getBoundingClientRect()
    mouseTarget.set(
      THREE.MathUtils.clamp(((event.clientX - rect.left) / rect.width) * 2 - 1, -1, 1),
      THREE.MathUtils.clamp(-((event.clientY - rect.top) / rect.height) * 2 + 1, -1, 1),
    )
    onPage = true
  }

  function onPointerLeave() {
    onPage = false
  }
</script>

<svelte:window onpointermove={onPointerMove} />
<svelte:document onmouseleave={onPointerLeave} />

<!-- the group sits at the middle of the beam so turning it pivots there -->
<T.Group bind:ref={beam} position={[beamCentre.x, beamCentre.y, 0]}>
  <T.Points {geometry} frustumCulled={false}>
    <T.ShaderMaterial
      {uniforms}
      transparent
      depthWrite={false}
      vertexShader={`
          attribute float sizes;
          attribute float shapes;
          attribute float rotations;
          attribute float spins;

          uniform float uTime;
          uniform vec2 uBeamDirection;
          uniform float uBeamHalfLength;
          uniform float uBeamWidth;
          uniform float uBeamDepth;
          uniform float uGlowRoom;

          varying float vSeed;
          varying float vAngle;
          varying float vFade;

          void main() {
            vSeed = shapes;
            vAngle = rotations + uTime * spins;

            // fall down the beam a couple of times quicker than the particles drift, wrapping back to the top
            float speed = 0.09 + shapes * 0.07;
            float along = mod(position.x + uBeamHalfLength + uTime * speed, uBeamHalfLength * 2.0) - uBeamHalfLength;
            float across = position.y;
            vec2 beamNormal = vec2(-uBeamDirection.y, uBeamDirection.x);
            // the beam starts narrow at the top right and spreads out as the shards fall, like light from a source
            float spread = mix(0.25, 1.0, smoothstep(-5.0, 3.0, along));
            vec3 p = vec3(uBeamDirection * along + beamNormal * across * spread, position.z * spread);

            // the few strays far from the centre line fade out, so the beam has no hard edge
            vFade = 1.0 - smoothstep(0.8, 2.5, length(vec2(across / uBeamWidth, position.z / uBeamDepth)));

            vec4 mvPosition = modelViewMatrix * vec4(p, 1.0);
            gl_Position = projectionMatrix * mvPosition;
            gl_PointSize = sizes * uGlowRoom * (300.0 / max(1.0, -mvPosition.z));

            // shards swung right up to the camera would fill the screen, so they fade out before they get there
            vFade *= smoothstep(1.0, 2.0, -mvPosition.z);
          }
        `}
      fragmentShader={`
            uniform float uGlowRoom;

            varying float vSeed;
            varying float vAngle;
            varying float vFade;

            float hash(float n) {
                return fract(sin(n) * 43758.5453);
            }

            // corner i of a shard: evenly spaced round the centre, each nudged in angle and pushed in or out so the
            // outline gets dents and bumps. sampled offline, these ranges keep every outward corner above 50 degrees
            vec2 corner(float i, float corners, float radius) {
                float spacing = 6.2831853 / corners;
                float a = (i + (hash(vSeed * 17.0 + i) * 2.0 - 1.0) * 0.3) * spacing;
                float r = radius * (1.0 + (hash(vSeed * 29.0 + i * 3.7) * 2.0 - 1.0) * 0.25);
                return r * vec2(cos(a), sin(a));
            }

            // signed distance to the outline, by Inigo Quilez: distance to the nearest edge, negative inside
            float outline(vec2 p, float corners, float radius) {
                vec2 previous = corner(corners - 1.0, corners, radius);
                float d = dot(p - previous, p - previous);
                float inside = 1.0;
                for (int i = 0; i < 12; i++) {
                    if (float(i) >= corners) break;
                    vec2 current = corner(float(i), corners, radius);
                    vec2 e = previous - current;
                    vec2 w = p - current;
                    vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
                    d = min(d, dot(b, b));
                    bvec3 crosses = bvec3(p.y >= current.y, p.y < previous.y, e.x * w.y > e.y * w.x);
                    if (all(crosses) || all(not(crosses))) inside = -inside;
                    previous = current;
                }
                return inside * sqrt(d);
            }

            void main() {
                vec2 uv = (gl_PointCoord - vec2(0.5)) * uGlowRoom;

                float c = cos(vAngle);
                float s = sin(vAngle);
                uv = mat2(c, -s, s, c) * uv;

                // a rough rock: 8-12 corners, drawn a touch smaller and then grown back out so they're just softened
                float corners = 8.0 + floor(hash(vSeed * 91.7) * 5.0);
                float rounding = 0.012;
                float d = outline(uv, corners, 0.3 - rounding) - rounding;

                float fill = 1.0 - smoothstep(-0.01, 0.01, d);

                // a soft glow spreading out from the outline into the space left round the shard
                float glow = exp(-max(d, 0.0) * 9.0) * 0.45;

                float alpha = max(fill * 0.92, glow) * vFade;
                if (alpha < 0.01) discard;

                gl_FragColor = vec4(vec3(1.0), alpha);
            }
        `}
    ></T.ShaderMaterial>
  </T.Points>
</T.Group>
