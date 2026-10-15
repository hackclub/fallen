#version 300 es

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

in vec3 position;
in float sizes;
in float shapes;
in float rotations;
in float spins;
in float fadeIns; // seconds this shard takes to fade in when the page opens

uniform float uTime;
uniform vec2 uBeamDirection;
uniform float uBeamHalfLength;
uniform float uBeamWidth;
uniform float uBeamDepth;
uniform float uGlowRoom;

out float vSeed;
out float vAngle;
out float vFade;

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

  // the hero's logo, tagline and buttons sit in the middle of the screen; shards passing behind them dim to a
  // quarter so they don't fight the text. An ellipse in screen space, so it keeps to the content at any aspect.
  vec2 screen = gl_Position.xy / gl_Position.w;
  float fromContent = length((screen - vec2(0.0, 0.03)) / vec2(0.45, 0.55));
  vFade *= mix(0.25, 1.0, smoothstep(0.6, 1.2, fromContent));

  vFade *= smoothstep(0.0, fadeIns, uTime);

  // an invisible shard still costs its whole sprite's fragments, and the near ones are hundreds of px across
  if (vFade < 0.01) gl_PointSize = 0.0;
}
