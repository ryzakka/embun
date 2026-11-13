#version 460 core
#include <flutter/runtime_effect.glsl>

// Efek bakar layar penuh untuk "Kartu terbakar" (night_impact.dart).
//
// Dipakai dua kali dengan uniform yang sama:
//   uMode = 0  lapisan api di atas layar (dinding api, tepi bara kartu,
//              lidah api yang memanjat, bara arang). Digambar dengan
//              BlendMode.plus.
//   uMode = 1  topeng kartu (ShaderMask + BlendMode.modulate): kartu
//              terlarut oleh derau mengikuti garis bakar dan menghitam
//              di dekat tepinya.

uniform vec2 uSize;    // ukuran area gambar (piksel)
uniform float uTime;   // detik sejak adegan mulai
uniform float uHeat;   // 0..1 kobaran dinding api
uniform float uBurn;   // 0..1 kemajuan garis bakar di kartu
uniform vec4 uCard;    // kiri, atas, lebar, tinggi kartu (piksel)
uniform float uMode;   // 0 = api layar, 1 = topeng kartu
uniform float uFade;   // 0..1 pemudaran akhir

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.7);
    a *= 0.5;
  }
  return v;
}

// 0..1 -> hitam, merah tua, oranye, kuning, putih panas.
vec3 fireRamp(float t) {
  t = clamp(t, 0.0, 1.0);
  vec3 c = vec3(0.0);
  c = mix(c, vec3(0.55, 0.05, 0.02), smoothstep(0.00, 0.30, t));
  c = mix(c, vec3(1.00, 0.38, 0.05), smoothstep(0.25, 0.55, t));
  c = mix(c, vec3(1.00, 0.82, 0.30), smoothstep(0.50, 0.80, t));
  c = mix(c, vec3(1.00, 0.98, 0.85), smoothstep(0.78, 1.00, t));
  return c;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / uSize.y;

  // Koordinat kartu 0..1 (y ke bawah) + garis bakar bergerigi oleh derau.
  vec2 cp = (frag - uCard.xy) / max(uCard.zw, vec2(1.0));
  float dis = fbm(cp * vec2(4.0, 6.0) + vec2(3.7, 1.3));
  float m = cp.y + (dis - 0.5) * 0.38;
  float front = 1.25 - 1.5 * uBurn;

  // ---- Mode 1: topeng kartu ----
  if (uMode > 0.5) {
    float burnt = smoothstep(front - 0.015, front + 0.015, m);
    float alpha = 1.0 - burnt;
    float dist = front - m;
    float charAmt = 1.0 - smoothstep(0.0, 0.18, dist);
    vec3 tint = mix(vec3(1.0), vec3(0.15, 0.07, 0.04), charAmt);
    fragColor = vec4(tint * alpha, alpha);
    return;
  }

  // ---- Mode 0: dinding api dari dasar layar ----
  float x = uv.x * aspect;
  float y = 1.0 - uv.y;
  float n1 = fbm(vec2(x * 3.2, y * 2.2 - uTime * 1.9));
  float n2 = fbm(vec2(x * 6.5 + n1 * 1.6, y * 3.4 - uTime * 3.1));
  float tongue = fbm(vec2(x * 2.4, uTime * 0.55 + 4.0));
  float hgt = uHeat * (0.30 + 0.70 * tongue) * 0.92;
  float body = clamp(1.0 - y / max(hgt, 0.001), 0.0, 1.0);
  float fl = body * (0.35 + 1.15 * n2);
  fl = smoothstep(0.10, 1.0, fl * 1.25);
  vec3 col = fireRamp(fl) * smoothstep(0.02, 0.22, fl);

  // Pendar hangat dari dasar layar.
  col += vec3(1.0, 0.34, 0.07) * exp(-y * 2.6) * uHeat * 0.30;

  // ---- Tepi bakar di kartu ----
  float rm = smoothstep(-0.15, 0.0, cp.x) * (1.0 - smoothstep(1.0, 1.15, cp.x))
           * smoothstep(-0.15, 0.0, cp.y) * (1.0 - smoothstep(1.0, 1.2, cp.y));
  float burning = step(0.001, uBurn) * (1.0 - step(0.999, uBurn));
  float band = abs(m - front);
  float edgeIn = exp(-band * 22.0);
  float flick = 0.75 + 0.5 * noise(frag * 0.08 + vec2(uTime * 14.0, 0.0));
  vec3 edgeCol = fireRamp(0.55 + 0.45 * edgeIn) * edgeIn * rm * flick * 1.6 * burning;

  // Lidah api memanjat di depan garis bakar.
  float up = front - m;
  float lickN = fbm(vec2(cp.x * 9.0, cp.y * 4.0 - uTime * 5.0));
  float lick = (1.0 - smoothstep(0.0, 0.30, up)) * step(0.0, up) * lickN * rm * burning;
  vec3 lickCol = fireRamp(lick * 1.3) * lick * 1.4;

  // Bara arang di bagian yang sudah hangus.
  float below = step(0.0, -up);
  float coalN = smoothstep(0.62, 0.85, fbm(cp * vec2(14.0, 20.0) + vec2(0.0, uTime * 0.6)));
  float coal = coalN * exp(-(m - front) * 4.0) * rm * below * burning;
  vec3 coalCol = vec3(1.0, 0.28, 0.04) * coal * 0.9;

  vec3 total = (col + edgeCol + lickCol + coalCol) * uFade;
  float a = clamp(max(max(total.r, total.g), total.b), 0.0, 1.0);
  fragColor = vec4(total, a);
}
