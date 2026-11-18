#version 460 core
#include <flutter/runtime_effect.glsl>

// Dua mode dalam satu shader (dipaintkan dengan BlendMode.plus):
//  uMode 0 = berkas cahaya volumetrik layar penuh (di belakang kartu)
//  uMode 1 = kilau foil yang menyapu muka kartu (di atas kartu)
// Urutan indeks float di Dart (TIDAK BERUBAH):
//  0,1 uSize | 2 uTime | 3 uMode | 4 uEnv | 5,6 uCenter | 7 uRadius
//  8-10 uSoft | 11-13 uHue
//
// Peningkatan mode 0: sinar tiga skala yang bernapas, cincin halo dan riak
// yang memuai, goresan lensa horizontal, serta debu bercahaya di dalam sinar.
// Peningkatan mode 1: dua sapuan berlawanan, garis difraksi pelangi, kilau
// berbentuk bintang empat sudut, cahaya yang berlari mengitari tepi kartu,
// dan tekstur foil halus.
uniform vec2 uSize;
uniform float uTime;
uniform float uMode;
uniform float uEnv;
uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uSoft;
uniform vec3 uHue;

out vec4 fragColor;

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

// Lutut lunak untuk satu nilai: rendah tetap linear, puncak digulung halus.
float knee(float x) {
  float over = max(x - 0.7, 0.0);
  return min(x, 0.7) + 0.3 * (1.0 - exp(-over / 0.3));
}

// Kilau bintang empat sudut: lengan tipis sepanjang sumbu x dan y.
float star4(vec2 a) {
  a = abs(a);
  return exp(-min(a.x, a.y) * 42.0) * exp(-max(a.x, a.y) * 7.0);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float t = uTime;

  if (uMode < 0.5) {
    // ---- berkas cahaya ----
    vec2 d = frag - uCenter;
    float R = max(uSize.x, uSize.y);
    float r = length(d) / R;
    float ang = atan(d.y, d.x);
    float a1 = ang + t * 0.12;
    // derau dibaca pada lingkaran agar tak ada sambungan di sudut +-pi
    float n1 = vnoise(vec2(cos(a1), sin(a1)) * 2.2 + vec2(t * 0.35, 3.0));
    float n2 = vnoise(vec2(cos(ang), sin(ang)) * 3.1 + vec2(-t * 0.2, t * 0.5 + 7.0));
    float rays = pow(clamp(0.5 + 0.5 * sin(a1 * 7.0 + n1 * 5.0), 0.0, 1.0), 3.0);
    rays += 0.6 * pow(clamp(0.5 + 0.5 * sin(ang * 13.0 - t * 0.2 + n2 * 4.0), 0.0, 1.0), 4.0);
    // lapis ketiga: sinar jarum tipis dan rapat
    float rays3 = pow(clamp(0.5 + 0.5 * sin(ang * 29.0 + n1 * 8.0 + t * 0.3), 0.0, 1.0), 10.0);
    float breath = 0.88 + 0.12 * sin(t * 0.8 + n1 * 3.0);
    float fall = exp(-r * 2.3) * (1.0 - smoothstep(0.62, 0.95, r));
    float core = exp(-r * r * 18.0);

    // halo: dua cincin tipis di sekitar inti, sedikit bernapas
    float hr1 = (r - (0.10 + 0.012 * sin(t * 1.1))) / 0.010;
    float hr2 = (r - 0.17) / 0.008;
    float halo = exp(-hr1 * hr1) + 0.5 * exp(-hr2 * hr2);
    // riak yang memuai keluar lalu memudar
    float rp = fract(t * 0.25);
    float rr = (r - rp * 0.9) / 0.02;
    float ripple = exp(-rr * rr) * (1.0 - rp) * (1.0 - rp);
    // goresan lensa horizontal tipis melintasi inti
    float flare = exp(-abs(d.y) / (R * 0.006)) * exp(-abs(d.x) / (R * 0.30));

    // debu bercahaya yang melayang naik di dalam sinar
    vec2 dg = frag / (R * 0.04) + vec2(t * 0.05, t * 0.12);
    vec2 dc = floor(dg);
    vec2 df = fract(dg) - 0.5;
    float dh = hash21(dc + 5.0);
    vec2 doff = (vec2(hash21(dc + 1.3), hash21(dc + 6.7)) - 0.5) * 0.6;
    float dd = length(df - doff);
    float dtw = 0.5 + 0.5 * sin(t * (1.0 + 2.0 * dh) + dh * 40.0);
    float dust = step(0.80, dh) * smoothstep(0.12, 0.0, dd) * dtw
               * clamp(rays * fall * 2.0, 0.0, 1.0);

    float k = uEnv * (0.34 * rays * fall * breath + 0.10 * rays3 * fall
                      + 0.22 * core + 0.08 * halo + 0.06 * ripple
                      + 0.10 * flare + 0.35 * dust);
    k = knee(k);
    vec3 c = mix(uSoft, vec3(1.0), core * 0.7);
    c = mix(c, uHue, clamp(halo * 0.6 + ripple * 0.5, 0.0, 1.0) * 0.6);
    fragColor = vec4(c * k, k);
    return;
  }

  // ---- kilau foil di muka kartu ----
  vec2 uv = frag / uSize;
  vec2 hq = abs(frag - 0.5 * uSize) - (0.5 * uSize - vec2(uRadius));
  float sd = length(max(hq, 0.0)) + min(max(hq.x, hq.y), 0.0) - uRadius;
  float mask = 1.0 - smoothstep(-0.6, 0.6, sd);

  // sapuan utama (diagonal) dan sapuan kedua yang lebih lambat berlawanan arah
  float sweep = fract(t * 0.16);
  float x = uv.x * 0.8 + uv.y * 0.55 - (sweep * 2.6 - 0.7);
  float dx2 = x - 0.30;
  float band = exp(-(x * x) / 0.010) + 0.45 * exp(-(dx2 * dx2) / 0.0025);
  float sweep2 = fract(t * 0.09 + 0.5);
  float x2 = uv.x * 0.55 - uv.y * 0.8 - (sweep2 * 2.4 - 0.6);
  float band2 = exp(-(x2 * x2) / 0.020) * 0.5;
  float bandAll = band + band2;

  // pelangi difraksi dengan garis halus di dalam pita
  vec3 holo = 0.5 + 0.5 * cos(TAU * (x * 1.6 + vec3(0.0, 0.33, 0.67)));
  float lines = 0.78 + 0.22 * sin((uv.x * 0.8 + uv.y * 0.55) * 140.0);
  vec3 tint = mix(uSoft, holo, 0.35 + 0.25 * clamp(band, 0.0, 1.0));
  tint *= mix(1.0, lines, clamp(band * 1.5, 0.0, 1.0));

  // butiran kilau halus
  vec2 g = floor(frag / 5.0);
  float tw = step(0.965, hash21(g + floor(t * 8.0 + hash21(g) * 8.0)));
  float glitter = tw * smoothstep(0.0, 0.5, bandAll + 0.15);

  // kilau bintang empat sudut: muncul, memuncak, lalu padam
  vec2 sg = frag / 11.0;
  vec2 sc = floor(sg);
  vec2 sf = fract(sg) - 0.5;
  float sh = hash21(sc + 17.0);
  float life = fract(t * 0.35 + sh);
  float flashAmt = pow(sin(life * 3.14159265), 6.0);
  vec2 so = (vec2(hash21(sc + 3.3), hash21(sc + 9.1)) - 0.5) * 0.5;
  float stars = step(0.93, sh) * star4(sf - so) * flashAmt
              * smoothstep(0.0, 0.6, bandAll + 0.2);

  // cahaya berlari mengitari tepi kartu
  float ang = atan(frag.y - 0.5 * uSize.y, frag.x - 0.5 * uSize.x);
  float chase = pow(clamp(0.5 + 0.5 * cos(ang - t * 1.2), 0.0, 1.0), 6.0);
  float rim = exp(min(sd, 0.0) * 0.35) * (0.5 + 0.5 * sin(t * 2.0));
  rim *= 0.55 + 0.9 * chase;

  // tekstur foil sangat halus di bawah sapuan
  float foil = vnoise(frag / 3.0) * clamp(bandAll, 0.0, 1.0);

  float k = uEnv * mask * (0.30 * band + 0.15 * band2
                           + 0.9 * glitter * (0.4 + bandAll)
                           + 0.7 * stars + 0.14 * rim + 0.04 * foil);
  k = knee(k);
  vec3 c = mix(tint, uHue, clamp(rim * 0.8, 0.0, 1.0));
  fragColor = vec4(c * k, k);
}
