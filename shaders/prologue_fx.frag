#version 460 core
#include <flutter/runtime_effect.glsl>

// Lapisan atmosfer prolog: kabut volumetrik, berkas cahaya, bulir melayang,
// serta denyut dan gelombang kejut benih hitam. Digambar DI ATAS gambar
// adegan. Keluaran premultiplied: kabut memakai alfa, cahaya bersifat aditif
// (rgb tanpa alfa), sehingga gambar di bawahnya tetap terlihat.
//
// Urutan uniform HARUS sama dengan _FogPainter di prologue_page.dart.

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
  float asp = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * asp, uv.y);
  float t = uTime;

  vec3 add = vec3(0.0);  // cahaya aditif
  float cover = 0.0;     // kabut (alfa)

  // ---- kabut: dua lapis fbm yang saling mendorong, lebih tebal di bawah
  vec2 q = p * vec2(1.3, 2.1);
  float f1 = fbm(q + vec2(t * 0.035, -t * 0.012));
  float f2 = fbm(q * 1.9 + vec2(-t * 0.05, t * 0.02) + f1 * 1.7);
  float shape = smoothstep(0.28, 0.86, f2);
  float lowBias = mix(0.5, 1.0, smoothstep(0.0, 1.0, uv.y));
  cover += shape * lowBias * uFog * 0.6;

  // ---- berkas cahaya: sinar radial dari sumber di atas layar
  vec2 L = vec2(uLightX * asp, -0.15);
  vec2 d = p - L;
  float ang = atan(d.x, d.y);
  float dist = length(d);
  float shaft = fbm(vec2(ang * 7.0 + t * 0.05, t * 0.08));
  shaft = smoothstep(0.36, 0.84, shaft);
  shaft *= exp(-dist * 1.1);
  shaft *= 0.75 + 0.25 * sin(t * 0.6 + ang * 9.0);
  // berkas tampak lebih jelas di dalam kabut
  add += uLightCol * shaft * uRays * 0.6 * (0.55 + 0.9 * f1);

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

  // ---- benih hitam: denyut cahaya ungu dan gelombang kejut
  vec2 sc = vec2(0.5 * asp, 0.36);
  float sd = distance(p, sc);
  vec3 violet = vec3(0.69, 0.49, 0.91);
  add += violet * uPulse * exp(-sd * 5.0) * 0.6;

  if (uShock > 0.0) {
    float R = uShock * 1.7;
    float z1 = (sd - R) / 0.04;
    float z2 = (sd - R * 0.72) / 0.022;
    float ring = exp(-z1 * z1) + 0.5 * exp(-z2 * z2);
    add += violet * ring * (1.0 - uShock) * 1.5;
    // kilatan tipis tepat saat hantaman
    add += violet * 0.25 * exp(-uShock * 9.0) * exp(-sd * 2.5);
  }

  // ---- kegelapan menekan dari tepi layar
  float edge = smoothstep(0.30, 1.05, length((uv - 0.5) * vec2(1.0, 1.25)));
  float dark = edge * uDark * 0.7;

  // butiran film halus (hanya menambah, supaya tetap sah sebagai premultiplied)
  add += vec3(hash21(frag + fract(t) * 91.7)) * 0.018;

  float a = clamp(cover * uIntro + dark * uIntro, 0.0, 1.0);
  vec3 rgb = uFogCol * cover * uIntro + add * uIntro;
  fragColor = vec4(clamp(rgb, 0.0, 1.0), a);
}
