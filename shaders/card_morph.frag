#version 460 core
#include <flutter/runtime_effect.glsl>

// Kartu baik larut menjadi kartu gelap: menggelap, retak bercahaya, glitch,
// lalu terbakar dari tengah ke tepi. Dipasang tepat di atas bidang kartu.
// Urutan indeks float di Dart (_MorphPainter):
//  0,1 uSize | 2 uProg | 3 uTime | 4 uRadius | 5 uSeed
//  6-8 uEdge | 9-11 uHot
// Sampler: 0 = uA (kartu baik), 1 = uB (kartu gelap)
uniform vec2 uSize;
uniform float uProg;    // 0..1 seluruh adegan putar balik
uniform float uTime;
uniform float uRadius;  // radius sudut kartu (px)
uniform float uSeed;
uniform vec3 uEdge;     // warna tepi terbakar (ungu)
uniform vec3 uHot;      // warna panas / retakan (ungu muda)
uniform sampler2D uA;
uniform sampler2D uB;

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

// x = jarak ke titik terdekat, y = jarak ke titik terdekat kedua
vec2 worley(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float d1 = 8.0;
  float d2 = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = vec2(hash21(i + g), hash21(i + g + 19.7));
      vec2 r = g + o - f;
      float d = dot(r, r);
      if (d < d1) {
        d2 = d1;
        d1 = d;
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  return vec2(sqrt(d1), sqrt(d2));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;

  // Bentuk kartu (sudut membulat)
  vec2 hq = abs(frag - 0.5 * uSize) - (0.5 * uSize - vec2(uRadius));
  float sd = length(max(hq, 0.0)) + min(max(hq.x, hq.y), 0.0) - uRadius;
  float mask = 1.0 - smoothstep(-0.6, 0.6, sd);
  if (mask <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  float P = clamp(uProg, 0.0, 1.0);
  float dark   = smoothstep(0.0, 0.30, P);
  float crack  = smoothstep(0.04, 0.34, P) * (1.0 - smoothstep(0.62, 0.92, P));
  float m      = smoothstep(0.30, 0.95, P);
  float glitch = smoothstep(0.30, 0.42, P) * (1.0 - smoothstep(0.55, 0.82, P));

  vec2 p = (uv - 0.5) * vec2(1.0, 1.5);   // satuan isotropik (kartu 2:3)
  float dist = length(p) / 0.9;

  // ---- kartu baik (A): glitch + aberasi warna ----
  float tick = floor(uTime * 24.0);
  float band = floor(uv.y * 26.0);
  float gate = step(0.62, hash21(vec2(band, tick + uSeed * 31.0)));
  vec2 uvA = uv;
  uvA.x += (hash21(vec2(band, 7.0 + tick)) - 0.5) * 0.12 * glitch * gate;
  vec2 ca = vec2(0.012, 0.0) * glitch;
  vec3 colA = vec3(texture(uA, clamp(uvA + ca, 0.0, 1.0)).r,
                   texture(uA, clamp(uvA, 0.0, 1.0)).g,
                   texture(uA, clamp(uvA - ca, 0.0, 1.0)).b);
  colA = mix(colA, vec3(0.04, 0.03, 0.08), dark * 0.62);

  // retakan bercahaya yang merambat dari tengah
  vec2 w = worley(p * 5.5 + uSeed * 9.0);
  float crk = 1.0 - smoothstep(0.0, 0.06, w.y - w.x);
  float crackR = 0.15 + P * 1.3;
  float reach = 1.0 - smoothstep(crackR - 0.15, crackR, dist);
  float cr = crk * reach * crack;
  colA = mix(colA, uHot, cr * 0.9);
  colA += uEdge * cr * 0.5;

  // ---- kartu gelap (B) ----
  vec3 colB = texture(uB, uv).rgb;

  // ---- larutan: dari tengah ke tepi, tepinya tak rata ----
  float field = 0.55 * dist + 0.45 * fbm(p * 4.0 + uSeed * 13.0);
  float thr = mix(-0.10, 1.10, m);
  float d = thr - field;                   // > 0 = sudah menjadi kartu gelap
  float inB = smoothstep(-0.012, 0.012, d);
  vec3 col = mix(colA, colB, inB);

  float onset = smoothstep(0.0, 0.06, m);
  float fadeEnd = 1.0 - smoothstep(0.96, 1.0, m);
  float charA = (1.0 - smoothstep(0.0, 0.112, -d)) * (1.0 - inB) * onset;
  col = mix(col, col * 0.25, charA * 0.7);

  float edgeGlow = exp(-abs(d) * 38.0);
  float hot = edgeGlow * onset * fadeEnd;
  col += mix(uEdge, uHot, smoothstep(0.2, 0.9, edgeGlow)) * hot * 1.6;

  // percik bara di sepanjang tepi
  float spark = step(0.97, hash21(floor(frag / 3.0) + floor(uTime * 18.0)));
  col += uHot * spark * exp(-abs(d) * 14.0) * onset * fadeEnd;

  col += uEdge * 0.10 * glitch;
  col = clamp(col, 0.0, 1.0);

  fragColor = vec4(col * mask, mask);  // premultiplied alpha
}