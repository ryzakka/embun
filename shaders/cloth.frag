#version 460 core
#include <flutter/runtime_effect.glsl>

// Urutan indeks float di Dart (ClothStyle):
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
const float BAND = 1.8;    // lebar kain sepanjang arah gerak (>1 = menutup penuh)
const float MARGIN = 0.25; // ruang agar kain mulai/berakhir di luar layar

float wave(float t, float time, float ph) {
  float f = uFreq;
  return sin(t * 5.0 * f - time * 4.0 + ph)
       + 0.5 * sin(t * 11.0 * f - time * 7.0 + 1.3 + ph * 1.7)
       + 0.25 * sin(t * 23.0 * f - time * 9.0 + ph * 2.3);
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

  float p = clamp(uProgress, 0.0, 1.0);
  float env = sin(PI * p);          // kibasan paling kuat di tengah
  float amp = (0.05 + 0.10 * env) * uAmp;
  float ph = uSeed * 6.2831853;

  float lead = -MARGIN + p * (1.0 + BAND + 2.0 * MARGIN);
  float edgeLead  = lead + 0.5 * amp * wave(t, uTime, ph);
  float edgeTrail = lead - BAND + 0.5 * amp * wave(t + 2.0, uTime * 1.1, ph + 1.0);

  float dFront = edgeLead - s;   // jarak ke tepi depan (>0 = di dalam kain)
  float dBack  = s - edgeTrail;  // jarak ke tepi belakang
  float inside = min(dFront, dBack);

  float a = smoothstep(0.0, 0.004, inside);
  if (a <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Koordinat motif menempel pada kain, digeser menurut seed
  vec2 c = vec2((s - lead) * L, t) * 7.0 + vec2(uSeed * 3.7, uSeed * 1.9);
  c += 0.15 * vec2(sin(t * 9.0 + uTime * 3.0), cos(s * 8.0 - uTime * 2.0));

  float m = motifMask(c);
  vec3 base = mix(uBaseA, uBaseB, 0.5 + 0.5 * sin(t * 2.0 + s * 3.0 + ph));
  vec3 col = mix(base, uAccent, m * 0.85);

  // Lipatan palsu + kilap benang
  float f = t * 10.0 + (s - lead) * 5.0 + 0.8 * sin(t * 4.0 - uTime * 3.0) - uTime * 2.0 + ph;
  float shade = 0.78 + 0.22 * cos(f);
  float spec = pow(max(cos(f + 0.9), 0.0), 10.0);
  vec3 glint = mix(vec3(1.0), uAccent, 0.35);
  col *= shade;
  col += glint * spec * 0.25 * (0.4 + m);

  // Pita selendang di tepi depan (tebal) dan belakang (tipis)
  float stripe = step(0.5, fract(t * 30.0)) * 0.12;
  vec3 ribbonCol = (uRibbon + stripe) * shade;
  float ribbonFront = 1.0 - smoothstep(0.050, 0.055, dFront);
  float ribbonBack  = 1.0 - smoothstep(0.022, 0.026, dBack);
  col = mix(col, ribbonCol, max(ribbonFront, ribbonBack));

  fragColor = vec4(col * a, a);  // premultiplied alpha
}
