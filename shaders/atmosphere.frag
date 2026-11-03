#version 460 core
#include <flutter/runtime_effect.glsl>

// Kabut embun + asap kelam untuk adegan pengungkapan peran.
// Urutan indeks float di Dart (_BackPainter._atmoPass):
//  0,1 uSize | 2 uTime | 3,4 uCenter | 5 uMist | 6 uPull | 7 uClear
//  8 uSmoke | 9 uCardW | 10 uCardH
//  11-13 uCol | 14-16 uNeutral | 17-19 uSmokeA | 20-22 uSmokeB
uniform vec2 uSize;
uniform float uTime;
uniform vec2 uCenter;   // pusat kartu (px)
uniform float uMist;    // kepekatan kabut (0 = tak ada)
uniform float uPull;    // 0..1, kabut merapat ke kartu
uniform float uClear;   // 0..1, kabut tersibak dari sekitar kartu
uniform float uSmoke;   // 0..1 kemajuan putar balik (0 = tanpa asap)
uniform float uCardW;
uniform float uCardH;
uniform vec3 uCol;      // warna kabut utama (emas -> warna peran)
uniform vec3 uNeutral;  // warna kabut netral
uniform vec3 uSmokeA;   // asap ungu
uniform vec3 uSmokeB;   // asap kelabu

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

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float m = max(uSize.x, uSize.y);
  vec2 rel = (frag - uCenter) / m;
  float dist = length(rel);
  float t = uTime;

  // ---- kabut ----
  float pullScale = 1.0 - 0.35 * uPull;
  vec2 p = rel / pullScale * 2.2;
  vec2 warp = vec2(fbm(p + vec2(t * 0.04, 0.0)),
                   fbm(p + vec2(5.2, 1.3 - t * 0.035)));
  float n  = fbm(p + 1.6 * warp + vec2(t * 0.02, -t * 0.015));
  float n2 = fbm(p * 0.8 + vec2(9.7, 3.1) + warp * 1.2 - t * 0.012);

  float body = smoothstep(0.30, 0.85, n);
  float ring = smoothstep(0.10, 0.65, dist);       // lebih pekat di tepi layar
  float cardR = 0.5 * max(uCardW, uCardH) / m;
  float clearR = cardR * 1.1 + uClear * 0.9;        // lubang tersibak melebar
  float hole = smoothstep(clearR * 0.55, clearR, dist);
  float holeMix = mix(1.0, hole, uClear);
  float dens = clamp(body * (0.35 + 0.65 * ring) * holeMix * uMist * 0.55, 0.0, 0.85);
  vec3 fogCol = mix(uNeutral, uCol, smoothstep(0.35, 0.65, n2));

  vec4 res = vec4(fogCol * dens, dens);

  // ---- asap kelam yang naik dari kartu (hanya putar balik) ----
  if (uSmoke > 0.0) {
    float sp = clamp((uSmoke - 0.28) / 0.62, 0.0, 1.0);
    float env = smoothstep(0.28, 0.40, uSmoke) * (1.0 - smoothstep(0.85, 1.0, uSmoke));
    float rise = (uCenter.y + 0.55 * uCardH - frag.y) / uCardH;  // 0 = dasar kartu
    float sx = (frag.x - uCenter.x) / uCardW;
    float head = 0.25 + 1.7 * sp;
    float vmask = smoothstep(-0.25, 0.10, rise) * (1.0 - smoothstep(head - 0.6, head, rise));
    float hmask = 1.0 - smoothstep(0.35, 1.5, abs(sx) * (0.8 + 0.5 * max(rise, 0.0)));
    vec2 q = vec2(sx * 1.7, rise * 1.2 - t * 0.55);
    float w1 = fbm(q * 1.3 + vec2(0.0, 3.0));
    float s = fbm(q * 1.5 + 1.8 * vec2(w1, fbm(q + 4.1)));
    float sd = smoothstep(0.32, 0.78, s) * vmask * hmask * env;
    float inky = smoothstep(0.35, 0.75, fbm(q * 0.9 + 11.0));
    vec3 sc = mix(uSmokeA, uSmokeB, inky);
    sc = mix(vec3(0.02, 0.01, 0.04), sc, smoothstep(0.25, 0.85, s));
    float sa = clamp(sd * 0.85, 0.0, 1.0);
    res = vec4(sc * sa, sa) + res * (1.0 - sa);
  }

  fragColor = res;  // premultiplied alpha
}