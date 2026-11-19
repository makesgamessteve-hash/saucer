/* SPDX-License-Identifier: MIT */
#include "sx_mesh.h"
#include <stdlib.h>
#include <string.h>
#include "sx_math.h"
#include "sx_rng.h"

void sx_mesh_init(sx_mesh *m) {
  memset(m, 0, sizeof *m);
  m->bmin[0] = m->bmin[1] = m->bmin[2] = 1e30f;
  m->bmax[0] = m->bmax[1] = m->bmax[2] = -1e30f;
}

void sx_mesh_free(sx_mesh *m) {
  free(m->v);
  free(m->idx);
  sx_mesh_init(m);
}

void sx_style_default(sx_part_style *s) {
  s->color[0] = s->color[1] = s->color[2] = 1.0f;
  s->emissive = 0.0f;
  s->uv_scale = 0.25f;
}

static int add_vertex(sx_mesh *m, const float p[3], const float n[3], float u, float v, const sx_part_style *s) {
  float *o;
  int i;
  if (m->nv == m->cap_v) {
    m->cap_v = m->cap_v ? m->cap_v * 2 : 256;
    m->v = (float *)realloc(m->v, sizeof(float) * SX_VTX_FLOATS * (size_t)m->cap_v);
  }
  o = m->v + SX_VTX_FLOATS * m->nv;
  for (i = 0; i < 3; i++) {
    o[i] = p[i];
    o[3 + i] = n[i];
    o[8 + i] = s->color[i];
    if (p[i] < m->bmin[i]) m->bmin[i] = p[i];
    if (p[i] > m->bmax[i]) m->bmax[i] = p[i];
  }
  o[6] = u;
  o[7] = v;
  o[11] = s->emissive;
  return m->nv++;
}

static void add_tri(sx_mesh *m, int a, int b, int c) {
  if (m->ni + 3 > m->cap_i) {
    m->cap_i = m->cap_i ? m->cap_i * 2 : 384;
    m->idx = (uint32_t *)realloc(m->idx, sizeof(uint32_t) * (size_t)m->cap_i);
  }
  m->idx[m->ni++] = (uint32_t)a;
  m->idx[m->ni++] = (uint32_t)b;
  m->idx[m->ni++] = (uint32_t)c;
}

static void normal_of(const float a[3], const float b[3], const float c[3], float n[3]) {
  float u[3], v[3], l;
  int i;
  for (i = 0; i < 3; i++) {
    u[i] = b[i] - a[i];
    v[i] = c[i] - a[i];
  }
  n[0] = u[1] * v[2] - u[2] * v[1];
  n[1] = u[2] * v[0] - u[0] * v[2];
  n[2] = u[0] * v[1] - u[1] * v[0];
  l = (float)sx_sqrt((double)(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]));
  if (l > 0) {
    n[0] /= l;
    n[1] /= l;
    n[2] /= l;
  }
}

/* Box projection: choose the plane by the dominant normal axis. */
static void box_uv(const float p[3], const float n[3], float sc, float *u, float *v) {
  float ax = n[0] < 0 ? -n[0] : n[0], ay = n[1] < 0 ? -n[1] : n[1], az = n[2] < 0 ? -n[2] : n[2];
  if (ax >= ay && ax >= az) {
    *u = p[2] * sc;
    *v = p[1] * sc;
  } else if (ay >= az) {
    *u = p[0] * sc;
    *v = p[2] * sc;
  } else {
    *u = p[0] * sc;
    *v = p[1] * sc;
  }
}

/* Flat-shaded quad a,b,c,d (CCW seen from outside). */
static void quad(sx_mesh *m, const float a[3], const float b[3], const float c[3], const float d[3],
                 const sx_part_style *s) {
  float n[3], u, v;
  int i0, i1, i2, i3;
  normal_of(a, b, c, n);
  box_uv(a, n, s->uv_scale, &u, &v);
  i0 = add_vertex(m, a, n, u, v, s);
  box_uv(b, n, s->uv_scale, &u, &v);
  i1 = add_vertex(m, b, n, u, v, s);
  box_uv(c, n, s->uv_scale, &u, &v);
  i2 = add_vertex(m, c, n, u, v, s);
  box_uv(d, n, s->uv_scale, &u, &v);
  i3 = add_vertex(m, d, n, u, v, s);
  add_tri(m, i0, i1, i2);
  add_tri(m, i0, i2, i3);
}

static void tri(sx_mesh *m, const float a[3], const float b[3], const float c[3], const sx_part_style *s) {
  float n[3], u, v;
  int i0, i1, i2;
  normal_of(a, b, c, n);
  box_uv(a, n, s->uv_scale, &u, &v);
  i0 = add_vertex(m, a, n, u, v, s);
  box_uv(b, n, s->uv_scale, &u, &v);
  i1 = add_vertex(m, b, n, u, v, s);
  box_uv(c, n, s->uv_scale, &u, &v);
  i2 = add_vertex(m, c, n, u, v, s);
  add_tri(m, i0, i1, i2);
}

static void set3(float *o, float x, float y, float z) {
  o[0] = x;
  o[1] = y;
  o[2] = z;
}

void sx_mesh_wedge(sx_mesh *m, const float mn[3], const float mx[3], float low, const sx_part_style *s) {
  float p[8][3], ht = mx[1] - mn[1];
  float yl = mn[1] + ht * low;
  /* bottom 0..3, top 4..7 (x0z0, x1z0, x1z1, x0z1) */
  set3(p[0], mn[0], mn[1], mn[2]);
  set3(p[1], mx[0], mn[1], mn[2]);
  set3(p[2], mx[0], mn[1], mx[2]);
  set3(p[3], mn[0], mn[1], mx[2]);
  set3(p[4], mn[0], mx[1], mn[2]);
  set3(p[5], mx[0], yl, mn[2]);
  set3(p[6], mx[0], yl, mx[2]);
  set3(p[7], mn[0], mx[1], mx[2]);
  quad(m, p[0], p[1], p[2], p[3], s); /* bottom (faces -y) */
  quad(m, p[4], p[7], p[6], p[5], s); /* top */
  quad(m, p[0], p[4], p[5], p[1], s); /* -z */
  quad(m, p[2], p[6], p[7], p[3], s); /* +z */
  quad(m, p[0], p[3], p[7], p[4], s); /* -x */
  if (low > 0.0f) quad(m, p[1], p[5], p[6], p[2], s); /* +x */
}

void sx_mesh_box(sx_mesh *m, const float mn[3], const float mx[3], const sx_part_style *s) {
  sx_mesh_wedge(m, mn, mx, 1.0f, s);
}

/* gap_half > 0 leaves out the segments whose middle lies within gap_half radians of azimuth gap_at
   * (atan2(x, z) as everywhere else): a doorway in a hull shell. */
static void frustum(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, int caps, float gap_at,
                    float gap_half, const sx_part_style *s) {
  int i;
  float top[3], bot[3];
  if (seg < 3) seg = 3;
  if (seg > 256) seg = 256;
  set3(bot, c[0], c[1], c[2]);
  set3(top, c[0], c[1] + h, c[2]);
  for (i = 0; i < seg; i++) {
    double a0 = SX_TAU * i / seg, a1 = SX_TAU * (i + 1) / seg;
    float s0, c0, s1, c1;
    float b0[3], b1[3], t0[3], t1[3];
    if (gap_half > 0.0f) {
      double d = (a0 + a1) / 2 - gap_at;
      while (d > SX_PI) d -= SX_TAU;
      while (d < -SX_PI) d += SX_TAU;
      if (d < 0) d = -d;
      if (d <= gap_half) continue;
    }
    s0 = (float)sx_sin(a0);
    c0 = (float)sx_cos(a0);
    s1 = (float)sx_sin(a1);
    c1 = (float)sx_cos(a1);
    set3(b0, c[0] + r0 * s0, c[1], c[2] + r0 * c0);
    set3(b1, c[0] + r0 * s1, c[1], c[2] + r0 * c1);
    set3(t0, c[0] + r1 * s0, c[1] + h, c[2] + r1 * c0);
    set3(t1, c[0] + r1 * s1, c[1] + h, c[2] + r1 * c1);
    if (r0 > 0 || r1 > 0) {
      if (r1 <= 0) tri(m, b0, b1, t0, s);
      else if (r0 <= 0) tri(m, b0, t1, t0, s);
      else quad(m, b0, b1, t1, t0, s);
    }
    if (caps && r1 > 0) tri(m, top, t0, t1, s);
    if (caps && r0 > 0) tri(m, bot, b1, b0, s);
  }
}

void sx_mesh_frustum(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, const sx_part_style *s) {
  frustum(m, c, r0, r1, h, seg, 1, 0.0f, 0.0f, s);
}

void sx_mesh_tube(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, const sx_part_style *s) {
  frustum(m, c, r0, r1, h, seg, 0, 0.0f, 0.0f, s);
}

void sx_mesh_tube_gap(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, float gap_at, float gap_half,
                      const sx_part_style *s) {
  frustum(m, c, r0, r1, h, seg, 0, gap_at, gap_half, s);
}

void sx_mesh_cylinder(sx_mesh *m, const float c[3], float r, float h, int seg, const sx_part_style *s) {
  sx_mesh_frustum(m, c, r, r, h, seg, s);
}

void sx_mesh_ring(sx_mesh *m, const float c[3], float rin, float rout, float h, int seg, const sx_part_style *s) {
  int i;
  if (seg < 3) seg = 3;
  if (seg > 256) seg = 256;
  for (i = 0; i < seg; i++) {
    double a0 = SX_TAU * i / seg, a1 = SX_TAU * (i + 1) / seg;
    float s0 = (float)sx_sin(a0), c0 = (float)sx_cos(a0), s1 = (float)sx_sin(a1), c1 = (float)sx_cos(a1);
    float ob0[3], ob1[3], ot0[3], ot1[3], ib0[3], ib1[3], it0[3], it1[3];
    float y0 = c[1], y1 = c[1] + h;
    set3(ob0, c[0] + rout * s0, y0, c[2] + rout * c0);
    set3(ob1, c[0] + rout * s1, y0, c[2] + rout * c1);
    set3(ot0, c[0] + rout * s0, y1, c[2] + rout * c0);
    set3(ot1, c[0] + rout * s1, y1, c[2] + rout * c1);
    set3(ib0, c[0] + rin * s0, y0, c[2] + rin * c0);
    set3(ib1, c[0] + rin * s1, y0, c[2] + rin * c1);
    set3(it0, c[0] + rin * s0, y1, c[2] + rin * c0);
    set3(it1, c[0] + rin * s1, y1, c[2] + rin * c1);
    quad(m, ob0, ob1, ot1, ot0, s); /* outer */
    quad(m, ib1, ib0, it0, it1, s); /* inner */
    quad(m, ot0, ot1, it1, it0, s); /* top */
    quad(m, ib0, ib1, ob1, ob0, s); /* bottom */
  }
}

void sx_mesh_dome(sx_mesh *m, const float c[3], float r, float h, int seg, int rings, const sx_part_style *s) {
  int i, j;
  if (seg < 3) seg = 3;
  if (seg > 256) seg = 256;
  if (rings < 1) rings = 1;
  if (rings > 64) rings = 64;
  for (j = 0; j < rings; j++) {
    double e0 = (SX_PI / 2) * j / rings, e1 = (SX_PI / 2) * (j + 1) / rings;
    float r0 = r * (float)sx_cos(e0), r1 = r * (float)sx_cos(e1);
    float y0 = c[1] + h * (float)sx_sin(e0), y1 = c[1] + h * (float)sx_sin(e1);
    for (i = 0; i < seg; i++) {
      double a0 = SX_TAU * i / seg, a1 = SX_TAU * (i + 1) / seg;
      float s0 = (float)sx_sin(a0), c0 = (float)sx_cos(a0), s1 = (float)sx_sin(a1), c1 = (float)sx_cos(a1);
      float b0[3], b1[3], t0[3], t1[3];
      set3(b0, c[0] + r0 * s0, y0, c[2] + r0 * c0);
      set3(b1, c[0] + r0 * s1, y0, c[2] + r0 * c1);
      set3(t0, c[0] + r1 * s0, y1, c[2] + r1 * c0);
      set3(t1, c[0] + r1 * s1, y1, c[2] + r1 * c1);
      if (j == rings - 1) tri(m, b0, b1, t0, s);
      else quad(m, b0, b1, t1, t0, s);
    }
  }
}

void sx_mesh_extrude(sx_mesh *m, const float *xz, int n, float y0, float y1, const sx_part_style *s) {
  int i;
  float cx = 0, cz = 0, ct[3], cb[3];
  if (n < 3) return;
  for (i = 0; i < n; i++) {
    cx += xz[2 * i];
    cz += xz[2 * i + 1];
  }
  cx /= (float)n;
  cz /= (float)n;
  set3(ct, cx, y1, cz);
  set3(cb, cx, y0, cz);
  for (i = 0; i < n; i++) {
    int k = (i + 1) % n;
    float a0[3], a1[3], b0[3], b1[3];
    set3(a0, xz[2 * i], y0, xz[2 * i + 1]);
    set3(a1, xz[2 * k], y0, xz[2 * k + 1]);
    set3(b0, xz[2 * i], y1, xz[2 * i + 1]);
    set3(b1, xz[2 * k], y1, xz[2 * k + 1]);
    quad(m, a0, b0, b1, a1, s); /* CCW polygon seen from +y -> sides face out */
    tri(m, ct, b1, b0, s);
    tri(m, cb, a0, a1, s);
  }
}

void sx_mesh_stars(sx_mesh *m, int count, float radius, float size, uint64_t seed) {
  sx_pcg32 r;
  sx_part_style s;
  int i;
  sx_style_default(&s);
  s.emissive = 1.0f;
  sx_pcg32_seed(&r, seed, 7);
  if (count > 20000) count = 20000;
  for (i = 0; i < count; i++) {
    /* uniform direction from two fixed-point draws */
    double z = (double)sx_pcg32_fixed(&r) / 32768.0 - 1.0;
    double a = (double)sx_pcg32_fixed(&r) / 65536.0 * SX_TAU;
    double q = sx_sqrt(1.0 - z * z);
    float d[3], up[3], rt[3], p[4][3], sz;
    float b = 0.5f + (float)sx_pcg32_bounded(&r, 128) / 255.0f;
    int k;
    d[0] = (float)(q * sx_cos(a));
    d[1] = (float)z;
    d[2] = (float)(q * sx_sin(a));
    /* tangent frame */
    if (d[1] > 0.9f || d[1] < -0.9f) set3(up, 1, 0, 0);
    else set3(up, 0, 1, 0);
    rt[0] = up[1] * d[2] - up[2] * d[1];
    rt[1] = up[2] * d[0] - up[0] * d[2];
    rt[2] = up[0] * d[1] - up[1] * d[0];
    {
      float l = (float)sx_sqrt((double)(rt[0] * rt[0] + rt[1] * rt[1] + rt[2] * rt[2]));
      for (k = 0; k < 3; k++) rt[k] /= l;
    }
    up[0] = d[1] * rt[2] - d[2] * rt[1];
    up[1] = d[2] * rt[0] - d[0] * rt[2];
    up[2] = d[0] * rt[1] - d[1] * rt[0];
    sz = size * (0.6f + (float)sx_pcg32_bounded(&r, 100) / 100.0f);
    for (k = 0; k < 3; k++) {
      float c = d[k] * radius;
      p[0][k] = c - rt[k] * sz - up[k] * sz;
      p[1][k] = c + rt[k] * sz - up[k] * sz;
      p[2][k] = c + rt[k] * sz + up[k] * sz;
      p[3][k] = c - rt[k] * sz + up[k] * sz;
    }
    s.color[0] = b;
    s.color[1] = b;
    s.color[2] = b * (0.85f + (float)sx_pcg32_bounded(&r, 30) / 100.0f);
    quad(m, p[0], p[3], p[2], p[1], &s); /* faces the origin */
  }
}

uint64_t sx_mesh_hash(const sx_mesh *m) {
  uint64_t h = sx_hash64(m->v, sizeof(float) * SX_VTX_FLOATS * (size_t)m->nv);
  return sx_hash64_combine(h, sx_hash64(m->idx, sizeof(uint32_t) * (size_t)m->ni));
}
