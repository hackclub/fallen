#version 300 es
precision highp float;

uniform float uGlowRoom;

in float vSeed;
in float vAngle;
in float vFade;

out vec4 fragColor;

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

  fragColor = vec4(vec3(1.0), alpha);
}
