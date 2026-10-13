#version 300 es
precision highp float;

in float vSeed;
in float vAngle;
in float vTumble;
in float vDiffuse;
in float vHover;
in float vFadeIn;

out vec4 fragColor;

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
  float intensity = (alpha * mix(lit, 0.25, white) + halo) * vFadeIn;

  // additive blending multiplies rgb by alpha, so alpha is how much light gets added
  fragColor = vec4(light, clamp(intensity, 0.0, 1.0));
}
