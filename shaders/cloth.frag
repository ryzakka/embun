#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniform (urutan indeks float di Dart):
// 0,1 = uSize | 2 = uProgress | 3 = uTime
uniform vec2 uSize;
uniform float uProgress;
uniform float uTime;

out vec4 fragColor;

const float PI = 3.14159265;
const float BAND = 1.8;    // lebar kain sepanjang arah angin (>1 = menutup penuh di tengah)
const float MARGIN = 0.2;  // ruang agar kain mulai/berakhir di luar layar

// Arah angin: kiri-bawah -> kanan-atas (y ke atas). Ubah vec2 ini untuk sudut lain.
const vec2 WIND = vec2(1.0, 0.75);

// Palet dari sampel warga desa
const vec3 INDIGO = vec3(0.07, 0.09, 0.24);
const vec3 BROWN  = vec3(0.13, 0.07, 0.05);
const vec3 GOLD   = vec3(0.86, 0.64, 0.22);
const vec3 BRICK  = vec3(0.80, 0.36, 0.10);

float wave(float t, float time) {
  return sin(t * 5.0 - time * 4.0)
       + 0.5 * sin(t * 11.0 - time * 7.0 + 1.3)
       + 0.25 * sin(t * 23.0 - time * 9.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 q = (frag - 0.5 * uSize) / uSize.y;
  q.y = -q.y;

  vec2 dir = normalize(WIND);
  vec2 perp = vec2(-dir.y, dir.x);
  float aspect = uSize.x / uSize.y;
  float L = aspect * abs(dir.x) + abs(dir.y);

  float s = dot(q, dir) / L + 0.5;  // 0..1 sepanjang arah angin
  float t = dot(q, perp);           // posisi menyamping

  float p = clamp(uProgress, 0.0, 1.0);
  float env = sin(PI * p);          // kibasan paling kuat di tengah
  float amp = 0.05 + 0.10 * env;

  float lead = -MARGIN + p * (1.0 + BAND + 2.0 * MARGIN);
  float edgeLead  = lead + 0.5 * amp * wave(t, uTime);
  float edgeTrail = lead - BAND + 0.5 * amp * wave(t + 2.0, uTime * 1.1);

  float dFront = edgeLead - s;   // jarak ke tepi depan (>0 = di dalam kain)
  float dBack  = s - edgeTrail;  // jarak ke tepi belakang
  float inside = min(dFront, dBack);

  float a = smoothstep(0.0, 0.004, inside);
  if (a <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Koordinat motif menempel pada kain (ikut bergerak bersamanya)
  vec2 c = vec2((s - lead) * L, t) * 7.0;
  c += 0.15 * vec2(sin(t * 9.0 + uTime * 3.0), cos(s * 8.0 - uTime * 2.0));

  // Motif: kisi belah ketupat (ala kawung) + titik bunga emas
  vec2 g = fract(c) - 0.5;
  float diamond = abs(abs(g.x) + abs(g.y) - 0.38);
  float lattice = 1.0 - smoothstep(0.0, 0.035, diamond);
  float flower  = 1.0 - smoothstep(0.10, 0.13, length(g));
  vec2 g2 = fract(c + 0.5) - 0.5;
  float corner  = 1.0 - smoothstep(0.06, 0.09, length(g2));
  float motif = clamp(lattice * 0.8 + flower + corner * 0.7, 0.0, 1.0);

  vec3 base = mix(INDIGO, BROWN, 0.5 + 0.5 * sin(t * 2.0 + s * 3.0));
  vec3 col = mix(base, GOLD, motif * 0.85);

  // Lipatan palsu + kilap benang emas
  float f = t * 10.0 + (s - lead) * 5.0 + 0.8 * sin(t * 4.0 - uTime * 3.0) - uTime * 2.0;
  float shade = 0.78 + 0.22 * cos(f);
  float spec = pow(max(cos(f + 0.9), 0.0), 10.0);
  col *= shade;
  col += vec3(1.0, 0.85, 0.45) * spec * 0.25 * (0.4 + motif);

  // Pita selendang oranye di tepi depan (tebal) dan belakang (tipis)
  float stripe = step(0.5, fract(t * 30.0)) * 0.15;
  vec3 ribbonCol = (BRICK + stripe) * shade;
  float ribbonFront = 1.0 - smoothstep(0.050, 0.055, dFront);
  float ribbonBack  = 1.0 - smoothstep(0.022, 0.026, dBack);
  col = mix(col, ribbonCol, max(ribbonFront, ribbonBack));

  fragColor = vec4(col * a, a);  // premultiplied alpha
}
