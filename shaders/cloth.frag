#version 460 core
#include <flutter/runtime_effect.glsl>

// Urutan indeks float di Dart (ClothStyle) TIDAK BERUBAH:
//  0,1 uSize | 2 uProgress | 3 uTime
//  4,5 uWind | 6 uMotif | 7 uAmp | 8 uFreq | 9 uSeed
//  10-12 uBaseA | 13-15 uBaseB | 16-18 uAccent | 19-21 uRibbon
uniform vec2 uSize;
uniform float uProgress;
uniform float uTime;
uniform vec2 uWind;     // arah gerak kain (y positif = ke atas layar)
uniform float uMotif;   // 0 = kawung, 1 = lurik bergaris, 2 = bunga
uniform float uAmp;     // kekuatan kibasan (1.0 = normal)
uniform float uFreq;    // kerapatan gelombang tepi (1.0 = normal)
uniform float uSeed;    // 0..1, membuat tiap sapuan sedikit berbeda
uniform vec3 uBaseA;    // warna dasar kain
uniform vec3 uBaseB;    // warna dasar kedua (bergradasi)
uniform vec3 uAccent;   // warna motif / benang
uniform vec3 uRibbon;   // warna pita selendang di tepi

out vec4 fragColor;

const float PI = 3.14159265;
const float BAND = 2.2;    // lebar kain sepanjang arah gerak (>1 = menutup penuh)
const float MARGIN = 0.4;  // ruang agar kain, selubung, dan bayangan mulai/berakhir di luar layar

float wave(float t, float time, float ph) {
  float f = uFreq;
  return sin(t * 5.0 * f - time * 4.0 + ph)
       + 0.5 * sin(t * 11.0 * f - time * 7.0 + 1.3 + ph * 1.7)
       + 0.25 * sin(t * 23.0 * f - time * 9.0 + ph * 2.3);
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21) + uSeed * 17.0);
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Mengembalikan 0..1: seberapa kuat motif (benang aksen) di titik c.
float motifMask(vec2 c) {
  if (uMotif < 0.5) {
    // Kawung: kisi belah ketupat + titik bunga
    vec2 g = fract(c) - 0.5;
    float diamond = abs(abs(g.x) + abs(g.y) - 0.38);
    float lattice = 1.0 - smoothstep(0.0, 0.035, diamond);
    float flower = 1.0 - smoothstep(0.10, 0.13, length(g));
    vec2 g2 = fract(c + 0.5) - 0.5;
    float corner = 1.0 - smoothstep(0.06, 0.09, length(g2));
    return clamp(lattice * 0.8 + flower + corner * 0.7, 0.0, 1.0);
  } else if (uMotif < 1.5) {
    // Lurik: garis tebal + dua garis tipis + belah ketupat kecil di sela
    float u = fract(c.y * 0.5);
    float thick = 1.0 - smoothstep(0.05, 0.08, abs(u - 0.5));
    float thin = (1.0 - smoothstep(0.010, 0.022, abs(u - 0.22)))
               + (1.0 - smoothstep(0.010, 0.022, abs(u - 0.78)));
    vec2 dg = vec2(fract(c.x * 1.2) - 0.5, (u < 0.5 ? u : u - 1.0) * 3.0);
    float dia = 1.0 - smoothstep(0.16, 0.20, abs(dg.x) + abs(dg.y));
    return clamp(thick + thin * 0.8 + dia, 0.0, 1.0);
  }
  // Bunga: kelopak lima, berselang-seling per baris, titik kecil di sela
  vec2 fc = c * 0.9;
  fc.x += 0.5 * mod(floor(fc.y), 2.0);
  vec2 f = fract(fc) - 0.5;
  float r = length(f);
  float a = atan(f.y, f.x);
  float petal = 1.0 - smoothstep(0.0, 0.025, r - (0.12 + 0.07 * cos(5.0 * a)));
  float core = 1.0 - smoothstep(0.03, 0.045, r);
  vec2 f2 = fract(fc + 0.5) - 0.5;
  float speck = 1.0 - smoothstep(0.03, 0.05, length(f2));
  return clamp(petal * (1.0 - core * 0.8) + speck * 0.6, 0.0, 1.0);
}

// Titik embun berkilau: sel acak, sebagian kecil saja yang menyala.
float dew(vec2 c) {
  vec2 id = floor(c);
  vec2 f = fract(c) - 0.5;
  float h = hash21(id);
  float h2 = hash21(id + 7.31);
  vec2 off = (vec2(h, h2) - 0.5) * 0.55;
  float d = length(f - off);
  float size = 0.06 + 0.10 * hash21(id + 3.7);
  float tw = 0.5 + 0.5 * sin(uTime * (6.0 + 8.0 * h2) + h * 40.0);
  float on = step(0.45, h);
  float core = 1.0 - smoothstep(0.0, size, d);
  float halo = 1.0 - smoothstep(0.0, size * 3.2, d);
  return on * (core + 0.35 * halo * halo) * (0.35 + 0.65 * tw);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 q = (frag - 0.5 * uSize) / uSize.y;
  q.y = -q.y;

  vec2 dir = normalize(uWind);
  vec2 perp = vec2(-dir.y, dir.x);
  float aspect = uSize.x / uSize.y;
  float L = aspect * abs(dir.x) + abs(dir.y);

  float s = dot(q, dir) / L + 0.5;  // 0..1 sepanjang arah gerak
  float t = dot(q, perp);           // posisi menyamping

  // Percepatan lembut: pelan di awal, menyambar di tengah, mengendap di akhir.
  // Simetris di 0.5, jadi saat kain menutup penuh tetap tepat di tengah.
  float praw = clamp(uProgress, 0.0, 1.0);
  float p = mix(praw, praw * praw * (3.0 - 2.0 * praw), 0.65);
  float env = sin(PI * p);          // kibasan paling kuat di tengah
  float amp = (0.06 + 0.14 * env) * uAmp;
  float ph = uSeed * 6.2831853;

  float lead = -MARGIN + p * (1.0 + BAND + 2.0 * MARGIN);
  float edgeLead  = lead + 0.5 * amp * wave(t, uTime, ph);
  float edgeTrail = lead - BAND + 0.5 * amp * wave(t + 2.0, uTime * 1.1, ph + 1.0);
  // Selubung tipis yang mendahului kain utama
  float edgeVeil = edgeLead + 0.10 + 0.16 * env
                 + 0.05 * wave(t * 0.8 + 1.0, uTime * 0.9, ph + 2.0);

  float dFront = edgeLead - s;   // jarak ke tepi depan (>0 = di dalam kain)
  float dBack  = s - edgeTrail;  // jarak ke tepi belakang
  float inside = min(dFront, dBack);
  float outside = max(-inside, 0.0);

  vec4 res = vec4(0.0);

  // 1) Bayangan lembut di sekitar kain (memberi kesan kain melayang di atas meja)
  float edgeFade = smoothstep(0.0, 0.06, praw) * (1.0 - smoothstep(0.94, 1.0, praw));
  if (inside < 0.0) {
    float sh = 0.50 * exp(-outside * 6.5) * edgeFade;
    res = vec4(0.0, 0.0, 0.0, sh);
  }

  // 2) Selubung tipis berkilau di depan kain
  float dVeil = edgeVeil - s;
  if (dFront < 0.0 && dBack > 0.0 && dVeil > 0.0) {
    float fv = t * 14.0 + s * 9.0 - uTime * 3.0 + ph;
    vec3 vcol = mix(uRibbon, uAccent, 0.35) * (0.85 + 0.15 * cos(fv));
    float vA = 0.52 * smoothstep(0.0, 0.012, dVeil)
             * (0.72 + 0.28 * sin(t * 60.0 + uTime * 5.0))
             * (1.0 - 0.5 * smoothstep(0.0, 0.3, -dFront));
    vA *= edgeFade;
    res = vec4(vcol * vA, vA) + res * (1.0 - vA);
  }

  // 3) Rumbai benang di tepi depan kain
  if (dFront < 0.0 && dBack > 0.0) {
    float cell = floor(t * 85.0);
    float hh = hash21(vec2(cell, 3.0));
    float fl = 0.030 + 0.035 * hh;
    float sway = 0.006 * sin(uTime * 8.0 + cell * 0.7) * env;
    float fx = fract(t * 85.0 + sway * 85.0);
    float strand = 1.0 - smoothstep(0.14, 0.26, abs(fx - 0.5));
    float len = 1.0 - smoothstep(0.0, fl, -dFront);
    float fA = strand * len * edgeFade;
    vec3 fcol = mix(uAccent, vec3(1.0), 0.12 * hh);
    res = vec4(fcol * fA, fA) + res * (1.0 - fA);
  }

  // 4) Embun berkilau terbawa angin, di depan dan di belakang kain
  if (inside < 0.0) {
    vec2 pc = vec2((s - lead) * L * 20.0 + uTime * 3.0, t * 20.0);
    float g = dew(pc) * exp(-outside * 4.5) * edgeFade * (0.5 + 0.5 * env);
    vec3 gcol = mix(uAccent, vec3(1.0), 0.55);
    res = clamp(res + vec4(gcol * g, g), 0.0, 1.0);
  }

  // 5) Badan kain
  float a = smoothstep(0.0, 0.004, inside);
  if (a > 0.0) {
    // Koordinat motif menempel pada kain, digeser menurut seed
    vec2 c = vec2((s - lead) * L, t) * 7.0 + vec2(uSeed * 3.7, uSeed * 1.9);
    c += 0.15 * vec2(sin(t * 9.0 + uTime * 3.0), cos(s * 8.0 - uTime * 2.0));

    float m = motifMask(c);
    vec3 base = mix(uBaseA, uBaseB, 0.5 + 0.5 * sin(t * 2.0 + s * 3.0 + ph));
    vec3 col = mix(base, uAccent, m * 0.85);

    // Lipatan: dua skala, makin dalam saat kain disambar
    float f = t * 10.0 + (s - lead) * 5.0
            + 0.8 * sin(t * 4.0 - uTime * 3.0) - uTime * 2.0 + ph;
    float f2 = t * 23.0 - (s - lead) * 8.0 + uTime * 3.0 + ph * 2.0;
    float shade = 0.74 + 0.20 * cos(f) + 0.06 * cos(f2);
    shade = mix(1.0, shade, 0.7 + 0.3 * env);
    float spec = pow(max(cos(f + 0.9), 0.0), 10.0);
    vec3 glint = mix(vec3(1.0), uAccent, 0.35);
    col *= shade;
    col += glint * spec * 0.28 * (0.4 + m);

    // Kilau lebar yang merambat di permukaan kain
    float sheen = pow(max(cos((s - lead) * 5.0 - uTime * 1.6 + t * 2.2), 0.0), 7.0);
    col += glint * sheen * 0.10;

    // Cahaya jatuh di dekat tepi depan, redup ke arah belakang
    float lit = 0.80 + 0.32 * exp(-dFront * 3.2);
    float dusk = mix(0.82, 1.0, smoothstep(0.0, 0.8, dBack));
    col *= lit * dusk;

    // Pita selendang di tepi depan (tebal) dan belakang (tipis)
    float stripe = step(0.5, fract(t * 30.0)) * 0.12;
    vec3 ribbonCol = (uRibbon + stripe) * shade;
    float ribbonFront = 1.0 - smoothstep(0.050, 0.055, dFront);
    float ribbonBack  = 1.0 - smoothstep(0.022, 0.026, dBack);
    col = mix(col, ribbonCol, max(ribbonFront, ribbonBack));

    // Benang emas tipis di sisi dalam pita, dan garis cahaya di tepi depan
    float thread = (1.0 - smoothstep(0.0, 0.0035, abs(dFront - 0.064)))
                 + (1.0 - smoothstep(0.0, 0.0025, abs(dBack - 0.034)));
    col = mix(col, uAccent, clamp(thread, 0.0, 1.0) * 0.85);
    float rim = exp(-dFront * 70.0) * (0.35 + 0.65 * env);
    col += mix(vec3(1.0), uAccent, 0.4) * rim * 0.45;

    res = vec4(col * a, a) + res * (1.0 - a);
  }

  fragColor = res;  // premultiplied alpha
}