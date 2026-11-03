#version 460 core
#include <flutter/runtime_effect.glsl>

// Dua mode dalam satu shader (dipaintkan dengan BlendMode.plus):
//  uMode 0 = berkas cahaya volumetrik layar penuh (di belakang kartu)
//  uMode 1 = kilau foil yang menyapu muka kartu (di atas kartu)
// Urutan indeks float di Dart:
//  0,1 uSize | 2 uTime | 3 uMode | 4 uEnv | 5,6 uCenter | 7 uRadius
//  8-10 uSoft | 11-13 uHue
uniform vec2 uSize;
uniform float uTime;
uniform float uMode;
uniform float uEnv;
uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uSoft;
uniform vec3 uHue;

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

void main() {
  vec2 frag = FlutterFragCoord().xy;

  if (uMode < 0.5) {
    // ---- berkas cahaya ----
    vec2 d = frag - uCenter;
    float R = max(uSize.x, uSize.y);
    float r = length(d) / R;
    float ang = atan(d.y, d.x);
    float a1 = ang + uTime * 0.12;
    // derau dibaca pada lingkaran agar tak ada sambungan di sudut +-pi
    float n1 = vnoise(vec2(cos(a1), sin(a1)) * 2.2 + vec2(uTime * 0.35, 3.0));
    float n2 = vnoise(vec2(cos(ang), sin(ang)) * 3.1 + vec2(-uTime * 0.2, uTime * 0.5 + 7.0));
    float rays = pow(clamp(0.5 + 0.5 * sin(a1 * 7.0 + n1 * 5.0), 0.0, 1.0), 3.0);
    rays += 0.6 * pow(clamp(0.5 + 0.5 * sin(ang * 13.0 - uTime * 0.2 + n2 * 4.0), 0.0, 1.0), 4.0);
    float fall = exp(-r * 2.3) * (1.0 - smoothstep(0.62, 0.95, r));
    float core = exp(-r * r * 18.0);
    float k = uEnv * (0.34 * rays * fall + 0.22 * core);
    vec3 c = mix(uSoft, vec3(1.0), core * 0.7);
    fragColor = vec4(c * k, k);
    return;
  }

  // ---- kilau foil di muka kartu ----
  vec2 uv = frag / uSize;
  vec2 hq = abs(frag - 0.5 * uSize) - (0.5 * uSize - vec2(uRadius));
  float sd = length(max(hq, 0.0)) + min(max(hq.x, hq.y), 0.0) - uRadius;
  float mask = 1.0 - smoothstep(-0.6, 0.6, sd);

  float sweep = fract(uTime * 0.16);
  float x = uv.x * 0.8 + uv.y * 0.55 - (sweep * 2.6 - 0.7);
  float dx2 = x - 0.30;
  float band = exp(-(x * x) / 0.010) + 0.45 * exp(-(dx2 * dx2) / 0.0025);

  vec3 holo = 0.5 + 0.5 * cos(6.2831853 * (x * 1.6 + vec3(0.0, 0.33, 0.67)));
  vec3 tint = mix(uSoft, holo, 0.35);

  vec2 g = floor(frag / 5.0);
  float tw = step(0.965, hash21(g + floor(uTime * 8.0 + hash21(g) * 8.0)));
  float glitter = tw * smoothstep(0.0, 0.5, band + 0.15);

  float rim = exp(min(sd, 0.0) * 0.35) * (0.5 + 0.5 * sin(uTime * 2.0));
  float k = uEnv * mask * (0.30 * band + 0.9 * glitter * (0.4 + band) + 0.14 * rim);
  vec3 c = mix(tint, uHue, clamp(rim * 0.8, 0.0, 1.0));
  fragColor = vec4(c * k, k);
}