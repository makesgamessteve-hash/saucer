/* SPDX-License-Identifier: MIT */
#include "sx_material.h"
#include <string.h>
#include "sx_math.h"

void sx_material_default(sx_material *m) {
  int k;
  memset(m, 0, sizeof *m);
  m->spec = 16.0f;
  m->f0 = 0.04f;
  m->wobble[1] = 6.0f;
  m->wobble[2] = 8.0f;
  for (k = 0; k < 3; k++) {
    m->ramp_lo[k] = 0.0f;
    m->ramp_hi[k] = 1.0f;
  }
}

void sx_materials_reset(sx_materials *ms) {
  int i;
  ms->on = 0;
  ms->time = 0.0f;
  ms->matcap = 0;
  for (i = 0; i < SX_MAT_SLOTS; i++) sx_material_default(&ms->slot[i]);
}

static const char *MODES[] = {"off", "lite", "full"};
int sx_materials_mode_from_name(const char *name) {
  int i;
  if (!name) return -1;
  for (i = 0; i < 3; i++)
    if (strcmp(name, MODES[i]) == 0) return i;
  return -1;
}
const char *sx_materials_mode_name(int mode) { return (mode >= 0 && mode <= 2) ? MODES[mode] : "?"; }

int sx_material_kind_from_name(const char *name) {
  static const char *kinds[] = {"plain", "metal", "crystal", "organic"};
  int i;
  if (!name) return -1;
  for (i = 0; i < 4; i++)
    if (strcmp(name, kinds[i]) == 0) return i;
  return -1;
}

int sx_materials_pack(const sx_materials *ms, int mode, float out[SX_MAT_SLOTS * SX_MAT_VEC4 * 4]) {
  int i, k, n = 0;
  memset(out, 0, sizeof(float) * SX_MAT_SLOTS * SX_MAT_VEC4 * 4);
  for (i = 0; i < SX_MAT_SLOTS; i++) {
    const sx_material *m = &ms->slot[i];
    float *o = out + i * SX_MAT_VEC4 * 4;
    int kind = (mode == SX_MATERIALS_OFF || !ms->on || i == 0) ? SX_MAT_PLAIN : m->kind;
    float lite = mode == SX_MATERIALS_LITE ? 1.0f : 0.0f;
    if (kind < 0 || kind > SX_MAT_ORGANIC) kind = SX_MAT_PLAIN;
    o[0] = (float)kind;
    for (k = 0; k < 3; k++) {
      o[8 + k] = m->ramp_lo[k];
      o[12 + k] = m->ramp_hi[k];
      o[16 + k] = m->sss[k];
    }
    if (kind == SX_MAT_PLAIN) continue;
    n++;
    /* lite: crystals lose the refraction (reflect), organics their small ripples; breathing halves */
    o[1] = (kind == SX_MAT_CRYSTAL && lite > 0.0f) ? 0.0f : m->reflect;
    o[2] = m->spec;
    o[3] = m->f0;
    o[4] = m->emit;
    o[5] = (kind == SX_MAT_ORGANIC && lite > 0.0f) ? 0.0f : m->wobble[0];
    o[6] = m->wobble[1] > 0.5f ? m->wobble[1] : 0.5f;
    o[7] = m->wobble[2] > 0.1f ? m->wobble[2] : 0.1f;
    o[11] = m->breath * (lite > 0.0f ? 0.5f : 1.0f);
    o[15] = m->pulse;
    o[19] = m->wrap;
    o[20] = (kind == SX_MAT_CRYSTAL && lite == 0.0f) ? m->sparkle : 0.0f;
    o[21] = kind == SX_MAT_METAL ? m->brushed : 0.0f;
    o[22] = kind == SX_MAT_METAL ? m->ripple * (lite > 0.0f ? 0.5f : 1.0f) : 0.0f;
  }
  return n;
}

static float clamp01(float v) { return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v); }

/* x^40 by squaring (no libm pow: the core keeps to + - * / sqrt) */
static float pow40(float x) {
  float x2 = x * x, x4 = x2 * x2, x8 = x4 * x4, x16 = x8 * x8, x32 = x16 * x16;
  return x32 * x8;
}

void sx_matcap_bake(unsigned char *out, const float lights[][4], int nlights, float ambient) {
  int x, y, i;
  if (nlights > SX_MATCAP_LIGHTS) nlights = SX_MATCAP_LIGHTS;
  if (nlights < 0) nlights = 0;
  for (y = 0; y < SX_MATCAP_SIZE; y++) {
    for (x = 0; x < SX_MATCAP_SIZE; x++) {
      float nx = ((float)x + 0.5f) / SX_MATCAP_SIZE * 2.0f - 1.0f;
      float ny = 1.0f - ((float)y + 0.5f) / SX_MATCAP_SIZE * 2.0f;
      float r2 = nx * nx + ny * ny, nz, l = ambient;
      int q;
      if (r2 > 1.0f) { /* outside the disc: the rim, so a lookup that strays past the edge stays sane */
        float s = 1.0f / (float)sx_sqrt((double)r2);
        nx *= s;
        ny *= s;
        r2 = 1.0f;
      }
      nz = (float)sx_sqrt((double)(1.0f - r2));
      for (i = 0; i < nlights; i++) {
        const float *L = lights[i];
        float ll = (float)sx_sqrt((double)(L[0] * L[0] + L[1] * L[1] + L[2] * L[2]));
        float lx, ly, lz, ndl, hx, hy, hz, hl, ndh, sp;
        if (ll < 1e-6f) continue;
        lx = L[0] / ll;
        ly = L[1] / ll;
        lz = L[2] / ll;
        ndl = nx * lx + ny * ly + nz * lz;
        /* half vector between the light and the viewer (+z) */
        hx = lx;
        hy = ly;
        hz = lz + 1.0f;
        hl = (float)sx_sqrt((double)(hx * hx + hy * hy + hz * hz));
        ndh = hl > 1e-6f ? (nx * hx + ny * hy + nz * hz) / hl : 0.0f;
        sp = ndh > 0.0f ? pow40(ndh) : 0.0f;
        l += L[3] * (0.35f * clamp01(ndl) + 0.9f * sp);
      }
      /* the horizon of a mirror ball picks up the room: a soft bright band at the rim */
      l += 0.25f * (1.0f - nz) * (1.0f - nz) * (1.0f - nz);
      q = (int)(clamp01(l) * 15.0f + 0.5f); /* 16 bands */
      out[y * SX_MATCAP_SIZE + x] = (unsigned char)(1 + q * 254 / 15);
    }
  }
}

float sx_material_wobble(const sx_material *m, const float p[3], float t) {
  double tau = 6.283185307179586;
  double per = m->wobble[1] > 0.5f ? m->wobble[1] : 0.5;
  double sc = m->wobble[2] > 0.1f ? m->wobble[2] : 0.1;
  double ph = (p[0] + p[1] * 0.7 + p[2] * 1.3) / sc;
  return (float)(m->wobble[0] * sx_sin(tau * t / per + ph) + m->breath * sx_sin(tau * t / (3.0 * per)));
}
