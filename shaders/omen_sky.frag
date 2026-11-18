#version 460 core
#include <flutter/runtime_effect.glsl>

// Awan gelap bergulung yang menyala dari dalam saat petir menyambar.
// Urutan indeks float di Dart (_OmenPainter._skyShader), TIDAK BERUBAH:
//  0,1 uSize | 2 uTime | 3 uDens
//  4,5,6 uB0 (x, y, intensitas) | 7,8,9 uB1 | 10,11,12 uB2
//
// Peningkatan: awan kini punya sisi terang dan sisi bayangan menghadap
// sumber petir (pencahayaan volumetrik murah), tepi awan berkilau perak,
// sinar tembus celah awan, kilat berkedip renyah, vinyet gelap di tepi,
// bara ungu di inti awan tebal, tone-mapping lembut, dan butiran film.
uniform vec2 uSize;
uniform float uTime;
uniform float uDens;    // 0..1 kepekatan awan
uniform vec3 uB0;
uniform vec3 uB1;
uniform vec3 uB2;

out vec4 fragColor;

// Hash tanpa sin: stabil untuk koordinat besar.
float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
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

// Awan dekat: dipakai dua kali (di titik ini dan sedikit ke arah petir).
float cloudNear(vec2 uv, vec2 wp, float t, float dens) {
  return fbm(uv * vec2(1.1, 1.8) + wp * (1.1 + 0.5 * dens)
             + vec2(-t * 0.03, 0.0) + 8.0);
}

float bolt(vec3 b, vec2 frag) {
  float r = length(frag - b.xy) / uSize.y;
  return b.z * (exp(-r * r * 6.0) + 0.25 * exp(-r * 1.5));
}

// Sinar tembus celah awan yang memancar dari titik petir.
float boltRays(vec3 b, vec2 frag, float t) {
  if (b.z < 0.01) return 0.0;
  vec2 d = frag - b.xy;
  float r = length(d) / uSize.y;
  float ang = atan(d.y, d.x);
  float n = vnoise(vec2(cos(ang), sin(ang)) * 2.2 + vec2(t * 0.3, 1.0));
  float ray = pow(clamp(0.5 + 0.5 * sin(ang * 11.0 + n * 6.0), 0.0, 1.0), 5.0);
  return b.z * ray * exp(-r * 2.4);
}

// Lutut lunak: nilai rendah tetap linear, puncak digulung halus ke 1.0.
vec3 softKnee(vec3 x) {
  vec3 over = max(x - 0.7, vec3(0.0));
  return min(x, vec3(0.7)) + 0.3 * (vec3(1.0) - exp(-over / 0.3));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize.y;
  vec2 fr = frag / uSize;
  float t = uTime;
  float udens = clamp(uDens, 0.0, 1.0);

  // dua lapis awan: yang jauh pelan, yang dekat lebih cepat dan melengkung
  float farL = fbm(uv * vec2(1.4, 2.2) + vec2(t * 0.012, 0.0) + 3.0);
  vec2 wp = vec2(fbm(uv * 1.8 + vec2(0.0, t * 0.02)),
                 fbm(uv * 1.8 + vec2(4.0, -t * 0.015)));
  float nearL = cloudNear(uv, wp, t, udens);

  // vinyet gelap: tepi layar lebih pekat
  float vig = smoothstep(0.30, 0.85, length(fr - 0.5));
  float top = 1.0 - smoothstep(0.0, 0.95, fr.y);
  float cover = clamp(0.35 + 0.9 * top, 0.0, 1.0);
  float d1 = smoothstep(0.30, 0.75, farL) * 0.6;
  float d2 = smoothstep(0.38, 0.80, nearL);
  float dens = clamp((d1 + d2) * cover * udens * (1.0 + 0.30 * vig), 0.0, 0.95);

  // kilat dengan kedip renyah
  float crackle = 0.85 + 0.30 * vnoise(vec2(t * 38.0, 5.0));
  float L = (bolt(uB0, frag) + bolt(uB1, frag) + bolt(uB2, frag)) * crackle;

  // arah ke pusat berat petir, untuk sisi terang / bayangan awan
  float lw = uB0.z + uB1.z + uB2.z;
  float lit = 0.5;
  if (lw > 0.01) {
    vec2 lp = (uB0.xy * uB0.z + uB1.xy * uB1.z + uB2.xy * uB2.z) / lw;
    vec2 toL = lp - frag;
    float tl = length(toL);
    vec2 dir = tl > 1.0 ? toL / tl : vec2(0.0, -1.0);
    float nearS = cloudNear(uv + dir * 0.07, wp, t, udens);
    // di titik ini lebih padat daripada ke arah petir = sisi yang tersinari
    lit = clamp(0.5 + (nearL - nearS) * 5.0, 0.0, 1.0);
  }

  vec3 dark = vec3(0.02, 0.008, 0.04);
  vec3 purple = vec3(0.165, 0.09, 0.27);
  vec3 lightCol = vec3(0.69, 0.49, 0.91);

  vec3 col = mix(dark, purple, nearL * 0.9);
  // bara ungu redup di inti awan tebal: awan terasa hidup meski tanpa petir
  float coreGlow = smoothstep(0.62, 0.92, nearL) * udens;
  col += purple * 0.35 * coreGlow * (0.6 + 0.4 * sin(t * 0.7 + nearL * 9.0));
  // cahaya petir: sisi menghadap petir lebih terang, sisi jauh tertinggal gelap
  col += (lightCol * 0.9 + 0.25) * L * (0.35 + 0.65 * d2) * (0.55 + 0.9 * lit);
  // tepi awan berkilau perak
  float rim = smoothstep(0.45, 0.62, nearL) - smoothstep(0.62, 0.80, nearL);
  col += lightCol * rim * L * 0.8 * (0.6 + 0.9 * lit);
  col += vec3(0.85, 0.80, 1.0) * rim * L * 0.25 * lit;

  // sinar tembus celah awan
  float rays = boltRays(uB0, frag, t) + boltRays(uB1, frag, t) + boltRays(uB2, frag, t);

  float a = clamp(dens + L * 0.18 * dens, 0.0, 0.97);
  float glow = clamp(L * 0.10 + rays * 0.06 * crackle, 0.0, 0.45);
  vec3 outc = col * a + lightCol * glow;

  // tone-mapping lembut dan butiran film halus
  outc = softKnee(outc);
  float gr = hash21(frag + vec2(fract(t * 5.37) * 97.0, fract(t * 2.91) * 61.0));
  outc *= 0.95 + 0.10 * gr;
  fragColor = vec4(outc, clamp(a + glow, 0.0, 1.0));
}
