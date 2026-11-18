#version 460 core
#include <flutter/runtime_effect.glsl>

// Lapisan atmosfer prolog: kabut volumetrik, berkas cahaya, bulir melayang,
// serta denyut dan gelombang kejut benih hitam. Digambar DI ATAS gambar
// adegan. Keluaran premultiplied: kabut memakai alfa, cahaya bersifat aditif
// (rgb tanpa alfa), sehingga gambar di bawahnya tetap terlihat.
//
// Urutan uniform HARUS sama dengan _FogPainter di prologue_page.dart
// (TIDAK BERUBAH dari versi sebelumnya).
//
// Peningkatan: kabut punya sisi terang menghadap cahaya dan lapisan kabut
// tanah, kabut merayap naik saat masuk adegan, berkas cahaya dua skala dengan
// bloom, bokeh di luar fokus, filamen spiral dan cincin kecil pada benih,
// gelombang kejut berpendar pelangi dengan percikan dan sisa cahaya,
// tone-mapping lembut, dan butiran film.

uniform vec2  uSize;      // 0,1
uniform float uTime;      // 2  detik
uniform float uP;         // 3  kemajuan adegan 0..1
uniform float uFog;       // 4  kepekatan kabut 0..1
uniform float uRays;      // 5  kekuatan berkas cahaya 0..1
uniform float uMotes;     // 6  banyaknya bulir 0..1
uniform float uLightX;    // 7  posisi mendatar sumber cahaya 0..1
uniform float uShock;     // 8  kemajuan gelombang kejut 0..1 (<0 = mati)
uniform float uIntro;     // 9  masuk adegan 0..1
uniform float uPulse;     // 10 denyut benih 0..1
uniform float uDark;      // 11 kegelapan menekan dari tepi 0..1
uniform vec3  uFogCol;    // 12,13,14
uniform vec3  uLightCol;  // 15,16,17

out vec4 fragColor;

const float PI = 3.14159265;
const float TAU = 6.2831853;

// Hash tanpa sin: stabil untuk koordinat besar, tanpa pola pita.
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

// Semburan percikan memanjang dari pusat. s = kemajuan 0..1, reach = jangkauan
// (satuan tinggi layar), count = jumlah sektor sudut.
float sparkBurst(float ang, float R, float s, float seed, float count,
                 float reach) {
  float cell = (ang + PI) / TAU * count;
  float id = floor(cell);
  float h = hash21(vec2(id, seed));
  float h2 = hash21(vec2(id, seed + 5.7));
  float fa = fract(cell) - 0.5 - (h2 - 0.5) * 0.5;
  float lateral = abs(fa) * R * TAU / count;
  float head = s * reach * (0.35 + 0.65 * h);
  float dr = R - head;
  float trail = smoothstep(-0.11, 0.0, dr) * (1.0 - smoothstep(0.0, 0.01, dr));
  float thin = exp(-lateral * lateral / 0.00005);
  return trail * thin * step(0.45, h) * pow(max(1.0 - s, 0.0), 1.3);
}

// Lutut lunak: nilai rendah tetap linear, puncak digulung halus ke 1.0.
vec3 softKnee(vec3 x) {
  vec3 over = max(x - 0.7, vec3(0.0));
  return min(x, vec3(0.7)) + 0.3 * (vec3(1.0) - exp(-over / 0.3));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float asp = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * asp, uv.y);
  float t = uTime;
  float intro = clamp(uIntro, 0.0, 1.0);

  vec3 add = vec3(0.0);  // cahaya aditif
  float cover = 0.0;     // kabut (alfa)

  // sumber cahaya di atas layar (selalu di atas p, jadi atan tanpa patahan)
  vec2 L = vec2(uLightX * asp, -0.15);
  vec2 d = p - L;
  float ang = atan(d.x, d.y);
  float dist = length(d);

  // ---- kabut: dua lapis fbm yang saling mendorong, lebih tebal di bawah
  vec2 q = p * vec2(1.3, 2.1);
  float f1 = fbm(q + vec2(t * 0.035, -t * 0.012));
  float f2 = fbm(q * 1.9 + vec2(-t * 0.05, t * 0.02) + f1 * 1.7);
  float shape = smoothstep(0.28, 0.86, f2);
  float lowBias = mix(0.5, 1.0, smoothstep(0.0, 1.0, uv.y));
  cover += shape * lowBias * uFog * 0.6;

  // sisi kabut yang menghadap cahaya: bandingkan dengan titik sedikit ke arah L
  vec2 toL = (L - p) / dist;
  vec2 qs = (p + toL * 0.06) * vec2(1.3, 2.1);
  float f2s = fbm(qs * 1.9 + vec2(-t * 0.05, t * 0.02) + f1 * 1.7);
  float lit = clamp(0.5 + (f2 - f2s) * 4.0, 0.0, 1.0);
  add += uLightCol * lit * shape * uRays * 0.20;

  // kabut tanah: lapisan rendah yang bergerak lebih lambat
  float gf = fbm(vec2(p.x * 0.9 + t * 0.02, p.y * 3.5 - t * 0.004) + 21.0);
  float ground = smoothstep(0.35, 0.80, gf) * smoothstep(0.55, 1.0, uv.y);
  cover += ground * uFog * 0.35;

  // kabut merayap naik dari bawah saat adegan masuk
  float reveal = clamp(intro * 1.8 - (1.0 - uv.y) * 0.7, 0.0, 1.0);
  cover = clamp(cover * reveal, 0.0, 1.0);

  // ---- berkas cahaya: sinar radial dari sumber di atas layar
  float shaft = fbm(vec2(ang * 7.0 + t * 0.05, t * 0.08));
  shaft = smoothstep(0.36, 0.84, shaft);
  shaft *= exp(-dist * 1.1);
  shaft *= 0.75 + 0.25 * sin(t * 0.6 + ang * 9.0);
  // sinar halus kedua, lebih rapat, memberi kesan debu di udara
  float shaft2 = pow(clamp(0.5 + 0.5 * sin(ang * 31.0 + shaft * 6.0 - t * 0.12), 0.0, 1.0), 6.0)
               * exp(-dist * 1.6) * 0.5;
  float breath = 0.92 + 0.08 * sin(t * 0.9);
  // berkas tampak lebih jelas di dalam kabut
  add += uLightCol * (shaft + shaft2) * uRays * 0.62 * (0.55 + 0.9 * f1) * breath;
  // bloom lembut di sekitar sumber cahaya
  add += uLightCol * exp(-dist * 2.2) * uRays * 0.12;

  // ---- bulir melayang: tiga lapis, makin jauh makin halus
  float m = 0.0;
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float scale = 7.0 + fk * 5.0;
    vec2 g = p * scale + vec2(0.0, t * (0.22 + 0.14 * fk)) + fk * 13.7;
    vec2 id = floor(g);
    vec2 fr = fract(g) - 0.5;
    float h = hash21(id + fk * 31.0);
    if (h > 0.55) {
      vec2 off = vec2(hash21(id + 7.3) - 0.5, hash21(id + 3.1) - 0.5) * 0.55;
      off.x += sin(t * 0.8 + h * 40.0) * 0.15;
      float dd = length(fr - off);
      float tw = 0.5 + 0.5 * sin(t * (1.5 + h * 3.0) + h * 50.0);
      float glow = smoothstep(0.09, 0.0, dd) + smoothstep(0.35, 0.0, dd) * 0.14;
      m += glow * tw * (1.0 - fk * 0.25);
    }
  }
  add += uLightCol * 1.1 * m * uMotes * 0.7;

  // bokeh besar di luar fokus, paling terlihat dekat sumber cahaya
  {
    vec2 bg = p * 2.4 + vec2(t * 0.02, t * 0.05) + 71.0;
    vec2 bid = floor(bg);
    vec2 bf = fract(bg) - 0.5;
    float bh = hash21(bid);
    if (bh > 0.72) {
      vec2 boff = (vec2(hash21(bid + 2.1), hash21(bid + 9.4)) - 0.5) * 0.5;
      float bd = length(bf - boff);
      float ringE = (bd - 0.18) / 0.02;
      float disc = smoothstep(0.20, 0.17, bd) * 0.6 + exp(-ringE * ringE) * 0.5;
      float btw = 0.5 + 0.5 * sin(t * 0.5 + bh * 30.0);
      add += uLightCol * disc * btw * uMotes * 0.14 * (0.4 + exp(-dist * 0.8));
    }
  }

  // ---- benih hitam: denyut cahaya ungu, filamen spiral, dan gelombang kejut
  vec2 sc = vec2(0.5 * asp, 0.36);
  vec2 sv = p - sc;
  float sd = length(sv);
  float sang = atan(sv.y, sv.x);
  vec3 violet = vec3(0.69, 0.49, 0.91);
  add += violet * uPulse * exp(-sd * 5.0) * 0.6;
  // filamen spiral yang berputar pelan di sekitar benih
  float spiral = pow(clamp(abs(sin(sang * 5.0 + sd * 18.0 - t * 1.4)), 0.0, 1.0), 8.0)
               * exp(-sd * 5.5);
  add += violet * spiral * uPulse * 0.30;
  // cincin kecil di dekat inti, memuai bersama denyut
  float pr = (sd - (0.06 + 0.05 * uPulse)) / 0.008;
  add += violet * exp(-pr * pr) * uPulse * 0.5;

  if (uShock > 0.0 && uShock < 1.0) {
    float s = uShock;
    float R = s * 1.7;
    // cincin utama berpendar pelangi (tiap kanal melaju sedikit berbeda)
    vec3 z1 = (vec3(sd) - R * vec3(1.0, 1.03, 1.06)) / 0.04;
    float z2 = (sd - R * 0.72) / 0.022;
    float z3 = (sd - R * 0.45) / 0.012;
    vec3 rings = exp(-z1 * z1)
               + vec3(0.5 * exp(-z2 * z2) + 0.35 * exp(-z3 * z3));
    add += violet * rings * (1.0 - s) * 1.5;
    // kilatan tipis tepat saat hantaman
    add += violet * 0.25 * exp(-s * 9.0) * exp(-sd * 2.5);
    // percikan yang melesat dan sisa cahaya yang bertahan sesaat
    add += mix(violet, vec3(1.0), 0.4) * sparkBurst(sang, sd, s, 17.0, 26.0, 1.0) * 0.9;
    add += violet * 0.10 * exp(-sd * 3.0) * (1.0 - s) * smoothstep(0.05, 0.30, s);
  }

  // ---- kegelapan menekan dari tepi layar
  float edge = smoothstep(0.30, 1.05, length((uv - 0.5) * vec2(1.0, 1.25)));
  float dark = edge * uDark * 0.7;

  // ---- penutup: tone-mapping lembut dan butiran film
  vec3 fogC = uFogCol * (0.78 + 0.35 * lit);
  vec3 rgb = fogC * cover * intro + add * intro;
  rgb = softKnee(rgb);
  // sedikit warna kabut di tepi gelap agar tidak hitam mati
  rgb += uFogCol * dark * 0.10 * intro;
  // butiran film halus (hanya menambah, supaya tetap sah sebagai premultiplied)
  rgb += vec3(hash21(frag + fract(t) * 91.7)) * 0.018;

  float a = clamp(cover * intro + dark * intro, 0.0, 1.0);
  fragColor = vec4(clamp(rgb, 0.0, 1.0), a);
}
