#version 460 core
#include <flutter/runtime_effect.glsl>

// Efek klaim medali: kilatan, cincin gelombang kejut, sinar, percikan, bara.
uniform vec2 uSize;
uniform vec2 uCenter;    // pusat medali (px)
uniform float uProgress; // 0..1 sejak medali menghantam
uniform float uTime;     // detik sejak dialog dibuka

out vec4 fragColor;

const float PI = 3.14159265;
const float TAU = 6.2831853;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float sparks(vec2 p, float a, float t, float cells, float seed) {
  float id = floor((a + PI) / TAU * cells);
  float h = hash(vec2(id, seed));
  float h2 = hash(vec2(id + 11.0, seed + 3.0));
  float ang = (id + 0.2 + 0.6 * h2) / cells * TAU - PI;
  float travel = (0.25 + 0.75 * h) * (1.0 - exp(-t * 3.5)) * 0.9 + 0.08;
  vec2 sp = travel * vec2(cos(ang), sin(ang));
  float d = length(p - sp);
  float life = 1.0 - smoothstep(0.35 + 0.5 * h2, 1.0, t);
  float tw = 0.6 + 0.4 * sin(uTime * 14.0 + h * 40.0);
  return life * tw * 0.0006 / (d * d + 0.00035);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float m = min(uSize.x, uSize.y);
  vec2 p = (frag - uCenter) / m;
  float r = length(p);
  float a = atan(p.y, p.x);
  float t = clamp(uProgress, 0.0, 1.0);

  vec3 gold = vec3(1.0, 0.78, 0.30);
  vec3 hot = vec3(1.0, 0.95, 0.75);
  vec3 leaf = vec3(0.47, 0.77, 0.56);
  vec3 col = vec3(0.0);

  // Kilatan saat hantaman.
  col += hot * exp(-t * 6.0) * 1.6 * exp(-r * 4.0);

  // Aura yang menetap dan berdenyut.
  float aura = smoothstep(0.0, 0.3, t);
  col += (gold * 0.55 + leaf * 0.12) * aura * exp(-r * 4.5)
         * (0.85 + 0.15 * sin(uTime * 2.5));

  // Sinar berputar.
  float ang = a + uTime * 0.25;
  float rays = pow(abs(sin(ang * 7.0)), 12.0) * 0.6
             + pow(abs(sin(ang * 13.0 - uTime * 0.6)), 20.0) * 0.4;
  float rayMask = exp(-r * 2.4) * smoothstep(0.05, 0.22, r) * smoothstep(0.0, 0.3, t);
  col += gold * rays * rayMask * 0.8;

  // Tiga cincin gelombang kejut.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float rt = clamp((t - fi * 0.08) / 0.6, 0.0, 1.0);
    float rad = rt * (0.9 + fi * 0.25);
    float x = (r - rad) * 22.0;
    float ring = exp(-x * x) * (1.0 - rt) * step(0.001, rt);
    col += mix(gold, hot, 0.4) * ring * 1.3;
  }

  // Percikan dua lapis.
  float sp = sparks(p, a, t, 36.0, 1.0) + sparks(p, a, t, 23.0, 7.0);
  col += mix(gold, hot, 0.5) * sp;

  // Bara naik perlahan setelah ledakan.
  vec2 g = (frag / m) * 14.0 + vec2(0.0, uTime * 0.6);
  vec2 id = floor(g);
  vec2 f = fract(g) - 0.5;
  float h = hash(id);
  vec2 off = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.6;
  float tw = 0.5 + 0.5 * sin(uTime * 3.0 + h * TAU);
  float ember = step(0.72, h) * smoothstep(0.09, 0.0, length(f - off)) * tw;
  col += gold * ember * 0.8 * smoothstep(0.2, 0.6, t) * exp(-r * 1.1);

  // Premultiplied alpha: warna ditambahkan sebagai cahaya di atas latar gelap.
  col = 1.0 - exp(-col * 1.3);
  float al = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0);
  fragColor = vec4(col, al);
}
