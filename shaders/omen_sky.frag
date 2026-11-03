#version 460 core
#include <flutter/runtime_effect.glsl>

// Awan gelap bergulung yang menyala dari dalam saat petir menyambar.
// Urutan indeks float di Dart (_OmenPainter._skyShader):
//  0,1 uSize | 2 uTime | 3 uDens
//  4,5,6 uB0 (x, y, intensitas) | 7,8,9 uB1 | 10,11,12 uB2
uniform vec2 uSize;
uniform float uTime;
uniform float uDens;    // 0..1 kepekatan awan
uniform vec3 uB0;
uniform vec3 uB1;
uniform vec3 uB2;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * vnoise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

float bolt(vec3 b, vec2 frag) {
  float r = length(frag - b.xy) / uSize.y;
  return b.z * (exp(-r * r * 6.0) + 0.25 * exp(-r * 1.5));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize.y;
  float t = uTime;

  // dua lapis awan: yang jauh pelan, yang dekat lebih cepat dan melengkung
  float farL = fbm(uv * vec2(1.4, 2.2) + vec2(t * 0.012, 0.0) + 3.0);
  vec2 wp = vec2(fbm(uv * 1.8 + vec2(0.0, t * 0.02)),
                 fbm(uv * 1.8 + vec2(4.0, -t * 0.015)));
  float nearL = fbm(uv * vec2(1.1, 1.8) + wp * 1.1 + vec2(-t * 0.03, 0.0) + 8.0);

  float top = 1.0 - smoothstep(0.0, 0.95, frag.y / uSize.y);
  float cover = clamp(0.35 + 0.9 * top, 0.0, 1.0);
  float d1 = smoothstep(0.30, 0.75, farL) * 0.6;
  float d2 = smoothstep(0.38, 0.80, nearL);
  float dens = clamp((d1 + d2) * cover * uDens, 0.0, 0.95);

  float L = bolt(uB0, frag) + bolt(uB1, frag) + bolt(uB2, frag);

  vec3 dark = vec3(0.02, 0.008, 0.04);
  vec3 purple = vec3(0.165, 0.09, 0.27);
  vec3 lightCol = vec3(0.69, 0.49, 0.91);

  vec3 col = mix(dark, purple, nearL * 0.9);
  col += (lightCol * 0.9 + 0.25) * L * (0.35 + 0.65 * d2);
  float rim = smoothstep(0.45, 0.62, nearL) - smoothstep(0.62, 0.80, nearL);
  col += lightCol * rim * L * 0.8;

  float a = clamp(dens + L * 0.18 * dens, 0.0, 0.97);
  float glow = clamp(L * 0.10, 0.0, 0.4);
  fragColor = vec4(col * a + lightCol * glow, clamp(a + glow, 0.0, 1.0));
}