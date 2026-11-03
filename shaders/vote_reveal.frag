#version 460 core
#include <flutter/runtime_effect.glsl>

// Latar adegan pembukaan suara (vote_reveal_scene). Dipaintkan layar penuh
// dengan BlendMode.plus di atas gradasi gelap, di belakang kartu dan papan.
// Empat lapis dalam satu shader:
//  1. kabut ketegangan: asap merah bergulung dari tepi layar, makin pekat
//     menurut uHeat dan berdenyut mengikuti uBeat;
//  2. hantaman suara penentu / vonis: gelombang kejut dua lapis, kilat inti,
//     dan semburan garis dari uCenter (uSlam = kemajuan 0..1, 0 = tak aktif);
//  3. vonis: berkas cahaya dari atas jatuh ke uCenter (uVerdict 0..1);
//  4. tanpa mayoritas: kabut dingin tenang dan butir cahaya melayang (uCalm).
// Urutan indeks float di Dart:
//  0,1 uSize | 2 uTime | 3 uHeat | 4 uBeat | 5 uSlam | 6,7 uCenter
//  8 uVerdict | 9 uCalm | 10-12 uHot | 13-15 uCool
uniform vec2 uSize;
uniform float uTime;
uniform float uHeat;
uniform float uBeat;
uniform float uSlam;
uniform vec2 uCenter;
uniform float uVerdict;
uniform float uCalm;
uniform vec3 uHot;
uniform vec3 uCool;

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
  vec2 uv = frag / uSize;
  vec2 p = (frag - 0.5 * uSize) / uSize.y; // tengah layar, satuan tinggi
  float t = uTime;
  float calm = clamp(uCalm, 0.0, 1.0);
  float heat = clamp(uHeat, 0.0, 1.0);
  float beat = clamp(uBeat, 0.0, 1.0);

  vec3 hot = uHot;
  vec3 cool = uCool;
  vec3 tint = mix(hot, cool, calm);
  vec3 acc = vec3(0.0);

  // ---- 1. kabut ketegangan ----
  vec2 q = vec2(p.x * 1.3, p.y * 1.3);
  float rise = t * (0.05 + 0.10 * heat);
  vec2 warp = vec2(fbm(q * 1.4 + vec2(0.0, -rise) + 2.0),
                   fbm(q * 1.4 + vec2(5.0, -rise * 0.7) + 9.0));
  float fog = fbm(q * 1.7 + warp * 1.2 + vec2(0.0, -rise * 1.4));
  float r = length((uv - 0.5) * vec2(1.0, 1.15));
  float edge = smoothstep(0.28, 0.80, r);
  float pulse = 0.55 + 0.45 * beat;
  float body = (0.10 + 0.62 * heat) * pulse * (1.0 - 0.55 * calm);
  float smoke = smoothstep(0.30, 0.85, fog);
  acc += tint * smoke * edge * body * 0.95;

  // bara panas dari bawah layar, hanya saat ketegangan tinggi
  float floorGlow = exp(-(1.0 - uv.y) * 3.2) * smoke;
  acc += hot * floorGlow * heat * heat * 0.22 * pulse * (1.0 - calm);

  // cincin tepi berdenyut
  float rim = smoothstep(0.52, 0.98, r) * beat * (0.05 + 0.22 * heat);
  acc += tint * rim * (1.0 - 0.6 * calm);

  // ---- 3. berkas cahaya vonis dari atas ----
  vec2 d = frag - uCenter;
  float R = length(d) / uSize.y;
  float ang = atan(d.y, d.x);
  float vd = clamp(uVerdict, 0.0, 1.0);
  if (vd > 0.001) {
    float width = uSize.y * (0.10 + 0.22 * clamp(uv.y, 0.0, 1.0));
    float dx = (frag.x - uCenter.x) / width;
    float shaft = exp(-dx * dx) * (1.0 - smoothstep(0.0, 1.05, uv.y) * 0.45);
    float dust = fbm(vec2(frag.x / uSize.y * 5.0, frag.y / uSize.y * 1.2 - t * 0.18));
    shaft *= 0.55 + 0.9 * dust;
    float n1 = vnoise(vec2(cos(ang), sin(ang)) * 2.4 + vec2(t * 0.25, 3.0));
    float rays = pow(clamp(0.5 + 0.5 * sin(ang * 9.0 + n1 * 5.0 - t * 0.15), 0.0, 1.0), 4.0);
    float fall = exp(-R * 2.2) * (1.0 - smoothstep(0.55, 0.95, R));
    float core = exp(-R * R * 14.0);
    vec3 beam = mix(vec3(1.0, 0.88, 0.80), hot, 0.45);
    acc += beam * vd * (0.16 * shaft + 0.10 * rays * fall + 0.12 * core);
  }

  // ---- 2. hantaman: gelombang kejut, kilat inti, garis memancar ----
  float s = uSlam;
  if (s > 0.001 && s < 0.999) {
    float inv = 1.0 - s;
    float R1 = s * 1.35;
    float w1 = 0.018 + 0.05 * s;
    float e1 = (R - R1) / w1;
    float ring1 = exp(-e1 * e1) * pow(inv, 1.4);
    float s2 = max(s - 0.12, 0.0);
    float R2 = s2 * 1.2;
    float w2 = 0.016 + 0.045 * s2;
    float e2 = (R - R2) / w2;
    float ring2 = exp(-e2 * e2) * pow(max(1.0 - s2, 0.0), 1.6) * step(0.12, s);
    float flashCore = exp(-R * R * 22.0) * pow(inv, 3.0);
    float spikeN = hash21(vec2(floor((ang + 3.14159) * 3.0), 7.0));
    float spikes = pow(clamp(abs(sin(ang * 14.0 + spikeN * 6.2832)), 0.0, 1.0), 10.0)
                 * exp(-R * 3.4) * pow(inv, 2.2);
    vec3 white = vec3(1.0, 0.92, 0.86);
    vec3 shock = mix(hot, white, 0.45);
    acc += shock * (0.55 * ring1 + 0.32 * ring2)
         + white * (0.55 * flashCore + 0.30 * spikes);
  }

  // ---- 4. tanpa mayoritas: kabut dingin dan butir melayang ----
  if (calm > 0.001) {
    float m = fbm(vec2(p.x * 1.4 + t * 0.03, p.y * 2.6 - t * 0.012) + 11.0);
    float band = smoothstep(0.36, 0.78, m);
    float zone = 1.0 - smoothstep(0.0, 0.95, abs(uv.y - 0.58) * 1.7);
    acc += cool * band * zone * calm * 0.20;

    vec2 g = vec2(frag.x / 26.0, (frag.y + t * 9.0) / 26.0);
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    float h = hash21(cell);
    vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 8.7)) - 0.5;
    float dd = length(f - off * 0.6);
    float tw = 0.5 + 0.5 * sin(t * (0.8 + 1.6 * h) + h * 40.0);
    float mote = step(0.86, h) * smoothstep(0.17, 0.0, dd) * tw;
    acc += mix(cool, vec3(1.0), 0.45) * mote * calm * 0.55;
  }

  acc = clamp(acc, vec3(0.0), vec3(1.0));
  float k = max(acc.r, max(acc.g, acc.b));
  fragColor = vec4(acc, k);
}
