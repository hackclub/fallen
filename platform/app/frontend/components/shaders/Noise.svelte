<script lang="ts">
  // film grain drawn over the whole page. it outputs grey around 0.5; the canvas is blended with
  // mix-blend-mode: overlay, so mid grey leaves the page as it is and the grain only lightens and darkens it
  import * as THREE from 'three'
  import { T, useTask, useThrelte } from '@threlte/core'
  import { prefersReducedMotion } from 'svelte/motion'

  const { dpr } = useThrelte()

  const uniforms = {
    uTime: { value: 0 },
    uGrainSize: { value: 1 },
  }

  useTask((delta) => {
    if (!prefersReducedMotion.current) uniforms.uTime.value += delta // a still grain instead of a flickering one
    uniforms.uGrainSize.value = dpr.current // one grain per css pixel, so it isn't finer on high density screens
  })

  // a quad covering the whole screen; the vertex shader skips the camera so it always fills the canvas
  const geometry = new THREE.PlaneGeometry(2, 2)
</script>

<T.Mesh {geometry} frustumCulled={false}>
  <T.ShaderMaterial
    {uniforms}
    depthTest={false}
    depthWrite={false}
    vertexShader={`
          void main() {
            gl_Position = vec4(position.xy, 0.0, 1.0);
          }
        `}
    fragmentShader={`
            uniform float uTime;
            uniform float uGrainSize;

            const float FPS = 18.0; // a new grain pattern this many times a second, like film running through a projector
            const float STRENGTH = 0.5; // how far the grain swings either side of mid grey

            // integer hash, so the pattern doesn't show the banding sin() based hashes get at large coordinates
            float hash(uvec3 v) {
                v = v * 1664525u + 1013904223u;
                v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
                v ^= v >> 16u;
                v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
                return float(v.x) / 4294967295.0;
            }

            void main() {
                uvec2 grain = uvec2(gl_FragCoord.xy / uGrainSize);
                uint frame = uint(floor(uTime * FPS));

                // average two samples so the grain clusters towards mid grey instead of being harsh salt and pepper
                float n = (hash(uvec3(grain, frame)) + hash(uvec3(grain, frame + 7919u))) * 0.5;

                gl_FragColor = vec4(vec3(0.5 + (n - 0.5) * STRENGTH * 2.0), 1.0);
            }
        `}
  ></T.ShaderMaterial>
</T.Mesh>
