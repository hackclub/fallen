#version 300 es

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

in vec3 position;
in float sizes;
in float shapes;
in float rotations;
in float spins;
in float fadeIns; // seconds this particle takes to fade in when the page opens

uniform float uTime;
uniform vec2 uMouse;
uniform float uHover;
uniform float uAspect;

out float vSeed;
out float vAngle;
out float vTumble;
out float vDiffuse;
out float vHover;
out float vFadeIn;

void main() {
  vec3 p = position;

  vSeed = shapes;
  vFadeIn = smoothstep(0.0, fadeIns, uTime);

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
