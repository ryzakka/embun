#version 460 core
#include <flutter/runtime_effect.glsl>

// Latar adegan pembukaan suara (vote_reveal_scene). Dipaintkan layar penuh
// dengan BlendMode.plus di atas gradasi gelap, di belakang kartu dan papan.
// Lapisan dalam satu shader:
//  1. kabut ketegangan: asap merah bergulung dari tepi layar dengan urat
//     terang, kedip, dan bara yang naik; makin pekat menurut uHeat dan
//     berdenyut mengikuti uBeat;
//  2. hantaman (uSlam): gelombang kejut berlapis berpendar pelangi, kilat
//     inti, garis anamorfik, semburan garis, percikan, dan sisa cahaya;
//  2b. suara mendarat (uHit, uHitPos): cincin ganda, kilat, dan percikan;
//  3. vonis (uVerdict): berkas cahaya jatuh dari atas ke uCenter, sinar
//     berputar, debu bercahaya, halo, dan riak denyut;
//  4. tanpa mayoritas (uCalm): kabut dingin berlapis dan butir melayang;
//  5. penutup: tone-mapping lembut (puncak cahaya tidak lagi terpotong
//     datar) dan butiran film halus.
//
// Urutan indeks float di Dart (TIDAK BERUBAH):
//  0,1 uSize | 2 uTime | 3 uHeat | 4 uBeat | 5 uSlam | 6,7 uCenter
//  8 uVerdict | 9 uCalm | 10-12 uHot | 13-15 uCool
//  16 uHit | 17,18 uHitPos
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
uniform float uHit;
uniform vec2 uHitPos;

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

// Noise sudut yang mulus melingkar (tanpa patahan di batas sudut).
float anoise(float ang, float k, vec2 shift) {
  return vnoise(vec2(cos(ang), sin(ang)) * k + shift);
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
  vec3 over = max(x - 0.6, vec3(0.0));
  return min(x, vec3(0.6)) + 0.4 * (vec3(1.0) - exp(-over / 0.4));
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
  vec3 white = vec3(1.0, 0.92, 0.86);
  vec3 ember = mix(hot, vec3(1.0, 0.78, 0.45), 0.55);
  vec3 acc = vec3(0.0);

  // ---- 1. kabut ketegangan ----
  vec2 q = p * 1.3;
  float rise = t * (0.05 + 0.10 * heat);
  vec2 warp = vec2(fbm(q * 1.4 + vec2(0.0, -rise) + 2.0),
                   fbm(q * 1.4 + vec2(5.0, -rise * 0.7) + 9.0));
  float fog = fbm(q * 1.7 + warp * (1.2 + 0.7 * heat) + vec2(0.0, -rise * 1.4));
  float r = length((uv - 0.5) * vec2(1.0, 1.15));
  float edge = smoothstep(0.28, 0.80, r);
  float pulse = 0.55 + 0.45 * beat;
  // kedip tak teratur, hanya terasa saat ketegangan tinggi
  float flick = 1.0 + heat * 0.7 * (vnoise(vec2(t * 7.0, 3.0)) - 0.5);
  float body = (0.10 + 0.62 * heat) * pulse * flick * (1.0 - 0.55 * calm);
  float smoke = smoothstep(0.30, 0.85, fog);
  // urat terang di dalam asap
  float wisp = pow(clamp(1.0 - abs(fog - 0.52) * 3.4, 0.0, 1.0), 2.5);
  acc += tint * smoke * edge * body * 0.95;
  acc += mix(tint, white, 0.35) * wisp * smoke * edge * body * 0.34;

  // bara panas dari bawah layar, hanya saat ketegangan tinggi
  float floorGlow = exp(-(1.0 - uv.y) * 3.2) * smoke;
  acc += hot * floorGlow * heat * heat * 0.26 * pulse * (1.0 - calm);

  // cincin tepi berdenyut
  float rim = smoothstep(0.52, 0.98, r) * beat * (0.05 + 0.22 * heat);
  acc += tint * rim * (1.0 - 0.6 * calm);

  // bara melayang naik (dua lapis, beda kedalaman)
  float emberAmt = heat * (1.0 - calm);
  if (emberAmt > 0.04) {
    for (int L = 0; L < 2; L++) {
      float fl = float(L);
      float cellSz = uSize.y * (0.055 - 0.020 * fl);
      float speed = uSize.y * (0.05 + 0.07 * heat) * (1.0 + 0.7 * fl);
      vec2 g = vec2(frag.x + sin(t * 0.6 + fl * 3.0) * cellSz * 0.4,
                    frag.y + t * speed) / cellSz;
      vec2 cell = floor(g);
      vec2 f = fract(g) - 0.5;
      float h = hash21(cell + fl * 17.0);
      vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 8.7)) - 0.5;
      off.x += 0.25 * sin(t * (1.0 + h * 2.0) + h * 30.0);
      float dd = length(f - off * 0.6);
      float tw = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * (2.0 + 3.0 * h) + h * 50.0), 2.0);
      float sparkle = step(0.80, h) * smoothstep(0.12, 0.0, dd) * tw;
      float lowAmt = mix(0.35, 1.0, uv.y);
      acc += ember * sparkle * emberAmt * lowAmt * (0.60 - 0.18 * fl)
           * (0.6 + 0.4 * beat);
    }
  }

  // ---- 3. berkas cahaya vonis dari atas ----
  vec2 d = frag - uCenter;
  float R = length(d) / uSize.y;
  float ang = atan(d.y, d.x);
  float vd = clamp(uVerdict, 0.0, 1.0);
  if (vd > 0.001) {
    // berkas jatuh dari atas: ujungnya turun seiring vd
    float reach = vd * 1.3;
    float drop = 1.0 - smoothstep(reach - 0.25, reach, uv.y);

    float width = uSize.y * (0.10 + 0.22 * clamp(uv.y, 0.0, 1.0));
    float dx = (frag.x - uCenter.x) / width;
    float shaft = exp(-dx * dx) * (1.0 - smoothstep(0.0, 1.05, uv.y) * 0.45);
    float dust = fbm(vec2(frag.x / uSize.y * 5.0, frag.y / uSize.y * 1.2 - t * 0.18));
    shaft *= (0.55 + 0.9 * dust) * drop;

    // garis inti tipis di dalam berkas, memudar di bawah yang dituduh
    float cx = (frag.x - uCenter.x) / (uSize.y * 0.012);
    float coreBeam = exp(-cx * cx) * drop
                   * (1.0 - smoothstep(0.0, 0.15, (frag.y - uCenter.y) / uSize.y))
                   * (1.0 - smoothstep(0.0, 0.9, uv.y) * 0.6);

    // butir debu bercahaya yang menangkap berkas
    vec2 dg = vec2(frag.x, frag.y - t * uSize.y * 0.04) / (uSize.y * 0.03);
    vec2 dcell = floor(dg);
    vec2 df = fract(dg) - 0.5;
    float dh = hash21(dcell + 41.0);
    vec2 doff = vec2(hash21(dcell + 1.7), hash21(dcell + 6.3)) - 0.5;
    float ddist = length(df - doff * 0.6);
    float dtw = 0.5 + 0.5 * sin(t * (1.0 + 2.0 * dh) + dh * 30.0);
    float grain = step(0.84, dh) * smoothstep(0.13, 0.0, ddist) * dtw;
    float inBeam = exp(-dx * dx * 0.8) * drop;

    float n1 = anoise(ang, 2.4, vec2(t * 0.25, 3.0));
    float rays = pow(clamp(0.5 + 0.5 * sin(ang * 9.0 + n1 * 5.0 - t * 0.15), 0.0, 1.0), 4.0);
    float rays2 = pow(clamp(0.5 + 0.5 * sin(ang * 23.0 - n1 * 7.0 + t * 0.20), 0.0, 1.0), 8.0);
    float fall = exp(-R * 2.2) * (1.0 - smoothstep(0.55, 0.95, R));
    float core = exp(-R * R * 14.0);
    vec3 beam = mix(vec3(1.0, 0.88, 0.80), hot, 0.45);
    acc += beam * vd * (0.18 * shaft + 0.11 * rays * fall + 0.07 * rays2 * fall
                        + 0.16 * core + 0.20 * coreBeam);
    acc += mix(beam, white, 0.4) * vd * grain * inBeam * 0.55;

    // halo berdenyut mengelilingi yang dituduh
    float hh1 = (R - 0.20) / 0.016;
    float hh2 = (R - 0.31) / 0.010;
    float halo = exp(-hh1 * hh1) + 0.5 * exp(-hh2 * hh2);
    // riak yang memuai keluar tiap detak panjang
    float rp = fract(t * 0.5);
    float hh3 = (R - (0.14 + 0.32 * rp)) / 0.012;
    halo += 0.8 * exp(-hh3 * hh3) * (1.0 - rp);
    acc += mix(hot, beam, 0.3) * vd * halo * (0.10 + 0.22 * beat);

    // goresan lensa horizontal tipis di pusat
    float lens = exp(-abs(d.y) / (uSize.y * 0.006))
               * exp(-abs(d.x) / (uSize.y * 0.35));
    acc += mix(beam, white, 0.5) * vd * lens * (0.10 + 0.08 * beat);
  }

  // ---- 2. hantaman: gelombang kejut, kilat inti, garis memancar ----
  float s = uSlam;
  if (s > 0.001 && s < 0.999) {
    float inv = 1.0 - s;
    float R1 = s * 1.35;
    float w1 = 0.018 + 0.05 * s;
    vec3 e1 = (vec3(R) - R1 * vec3(1.0, 1.04, 1.08)) / w1;
    vec3 ring1 = exp(-e1 * e1) * pow(inv, 1.4);
    float s2 = max(s - 0.12, 0.0);
    float R2 = s2 * 1.2;
    float w2 = 0.016 + 0.045 * s2;
    float e2 = (R - R2) / w2;
    float ring2 = exp(-e2 * e2) * pow(max(1.0 - s2, 0.0), 1.6) * step(0.12, s);
    // cincin ketiga: tipis, tajam, menyusul paling akhir
    float s3 = max(s - 0.25, 0.0);
    float e3 = (R - s3 * 1.05) / 0.008;
    float ring3 = exp(-e3 * e3) * pow(max(1.0 - s3, 0.0), 2.0) * step(0.25, s);
    // kilat inti dengan pinggir berpendar pelangi
    vec3 Rv = vec3(R) * vec3(1.0, 1.06, 1.12);
    vec3 flashCore = exp(-Rv * Rv * 22.0) * pow(inv, 3.0);
    // sinar anamorfik horizontal
    float streak = exp(-abs(d.y) / (uSize.y * 0.008))
                 * exp(-abs(d.x) / (uSize.y * (0.25 + 0.6 * s)))
                 * pow(inv, 2.0);
    // garis memancar dengan fase mulus (tanpa patahan antar sektor)
    float spikeN = anoise(ang, 1.6, vec2(7.0, 2.0));
    float spikes = pow(clamp(abs(sin(ang * 14.0 + spikeN * 6.2832)), 0.0, 1.0), 10.0)
                 * exp(-R * 3.4) * pow(inv, 2.2);
    // percikan yang melesat
    float sparks = sparkBurst(ang, R, s, 13.0, 28.0, 1.1);
    // sisa cahaya hangat yang bertahan sesaat
    float after = exp(-R * 2.6) * pow(inv, 1.2) * smoothstep(0.05, 0.35, s);
    vec3 shock = mix(hot, white, 0.45);
    acc += shock * (0.32 * ring2 + 0.30 * ring3)
         + ring1 * vec3(1.0, 0.94, 0.90) * 0.62
         + white * (0.34 * spikes) + flashCore * white * 0.60
         + white * (0.40 * streak) + ember * (0.70 * sparks)
         + hot * (0.16 * after)
         + shock * (0.06 * pow(inv, 6.0)); // kilat tipis seluruh layar
  }

  // ---- 2b. suara mendarat di kartu sasaran ----
  float hs = uHit;
  if (hs > 0.001 && hs < 0.999) {
    vec2 hd = frag - uHitPos;
    float HR = length(hd) / uSize.y;
    float hinv = 1.0 - hs;
    float hw = 0.012 + 0.03 * hs;
    float he = (HR - hs * 0.42) / hw;
    float hring = exp(-he * he) * pow(hinv, 1.5);
    float he2 = (HR - max(hs - 0.10, 0.0) * 0.30) / 0.010;
    float hring2 = exp(-he2 * he2) * pow(hinv, 2.0) * step(0.10, hs);
    float hflash = exp(-HR * HR * 70.0) * pow(hinv, 3.0);
    float hang = atan(hd.y, hd.x);
    float hspN = anoise(hang, 1.4, vec2(3.0, 5.0));
    float hspark = pow(clamp(abs(sin(hang * 9.0 + hspN * 6.2832)), 0.0, 1.0), 12.0)
                 * exp(-HR * 7.0) * pow(hinv, 2.0);
    float hburst = sparkBurst(hang, HR, hs, 21.0, 18.0, 0.30);
    acc += mix(hot, white, 0.4) * (0.50 * hring + 0.22 * hring2 + 0.25 * hspark)
         + ember * (0.65 * hburst)
         + white * 0.40 * hflash;
  }

  // ---- 4. tanpa mayoritas: kabut dingin dan butir melayang ----
  if (calm > 0.001) {
    float breathe = 0.88 + 0.12 * sin(t * 0.5);
    float m = fbm(vec2(p.x * 1.4 + t * 0.03, p.y * 2.6 - t * 0.012) + 11.0);
    float band = smoothstep(0.36, 0.78, m);
    float zone = 1.0 - smoothstep(0.0, 0.95, abs(uv.y - 0.58) * 1.7);
    acc += cool * band * zone * calm * 0.20 * breathe;
    // pita kedua, lebih lambat dan lebih pucat, memberi kedalaman
    float m2 = fbm(vec2(p.x * 0.9 - t * 0.02, p.y * 1.8 + t * 0.008) + 31.0);
    float band2 = smoothstep(0.42, 0.82, m2);
    float zone2 = 1.0 - smoothstep(0.0, 0.8, abs(uv.y - 0.40) * 1.9);
    acc += mix(cool, vec3(1.0), 0.35) * band2 * zone2 * calm * 0.10 * breathe;

    for (int L = 0; L < 2; L++) {
      float fl = float(L);
      float cs = 26.0 + 18.0 * fl;
      vec2 g = vec2(frag.x / cs, (frag.y + t * (9.0 - 4.0 * fl)) / cs);
      vec2 cell = floor(g);
      vec2 f = fract(g) - 0.5;
      float h = hash21(cell + fl * 23.0);
      vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 8.7)) - 0.5;
      float dd = length(f - off * 0.6);
      float tw = 0.5 + 0.5 * sin(t * (0.8 + 1.6 * h) + h * 40.0);
      float mote = step(0.86, h) * smoothstep(0.17, 0.0, dd) * tw;
      acc += mix(cool, vec3(1.0), 0.45) * mote * calm * (0.55 - 0.20 * fl);
    }
  }

  // ---- 5. penutup: tone-mapping lembut dan butiran film ----
  vec3 raw = max(acc, vec3(0.0));
  float peak = max(raw.r, max(raw.g, raw.b));
  vec3 col = softKnee(raw);
  // puncak yang sangat terang menuju putih panas
  float hi = smoothstep(0.7, 1.8, peak);
  col = mix(col, vec3(max(col.r, max(col.g, col.b))), hi * 0.55);
  // butiran film halus, hanya memodulasi cahaya yang sudah ada
  float gr = hash21(frag + vec2(fract(t * 7.13) * 113.0, fract(t * 3.71) * 57.0));
  col *= 0.94 + 0.12 * gr;
  col = clamp(col, vec3(0.0), vec3(1.0));
  float k = max(col.r, max(col.g, col.b));
  fragColor = vec4(col, k);
}
