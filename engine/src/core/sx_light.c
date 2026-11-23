/* SPDX-License-Identifier: MIT */
#include "sx_light.h"
#include <string.h>
#include "sx_math.h"
#include "sx_render.h"

static float dot3(const float a[3], const float b[3]) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
static void cross3(float o[3], const float a[3], const float b[3]) {
  o[0] = a[1] * b[2] - a[2] * b[1];
  o[1] = a[2] * b[0] - a[0] * b[2];
  o[2] = a[0] * b[1] - a[1] * b[0];
}
static void norm3(float v[3]) {
  float l = (float)sx_sqrt((double)dot3(v, v));
  if (l < 1e-9f) {
    v[0] = 0;
    v[1] = 1;
    v[2] = 0;
    return;
  }
  v[0] /= l;
  v[1] /= l;
  v[2] /= l;
}

void sx_lighting_reset(sx_lighting *lt) {
  lt->on = 0;
  lt->ambient[0] = lt->ambient[1] = lt->ambient[2] = 0.02f;
  lt->exposure = 1.0f;
  lt->has_focus = 0;
  lt->nlights = lt->dropped = 0;
  lt->nactive = 0;
  lt->cascades = lt->spots = lt->omni = 0;
  lt->atlas = 0;
  /* omni_key survives the reset: the omni blocks stay with their lights from frame to frame */
}

void sx_light_defaults(sx_light *l, int kind) {
  memset(l, 0, sizeof *l);
  l->kind = kind;
  l->dir[1] = kind == SX_LIGHT_SPOT ? -1.0f : 1.0f;
  l->color[0] = l->color[1] = l->color[2] = 1.0f;
  l->intensity = 1.0f;
  l->range = 10.0f;
  l->cos_inner = 0.9f;
  l->cos_outer = 0.8f;
  l->priority = 1.0f;
  l->slot = -1;
}

int sx_lighting_add(sx_lighting *lt, const sx_light *l) {
  sx_light *d;
  if (lt->nlights >= SX_MAX_LIGHTS) {
    lt->dropped++;
    return -1;
  }
  d = &lt->lights[lt->nlights];
  *d = *l;
  if (d->kind != SX_LIGHT_SUN && d->range < 0.1f) d->range = 0.1f;
  if (d->kind != SX_LIGHT_POINT) norm3(d->dir);
  if (d->cos_inner < d->cos_outer) d->cos_inner = d->cos_outer;
  d->slot = -1;
  d->score = 0;
  return lt->nlights++;
}

int sx_shadow_quality_from_name(const char *name) {
  if (!name) return -1;
  if (strcmp(name, "off") == 0) return SX_SHADOWS_OFF;
  if (strcmp(name, "low") == 0) return SX_SHADOWS_LOW;
  if (strcmp(name, "high") == 0) return SX_SHADOWS_HIGH;
  return -1;
}

const char *sx_shadow_quality_name(int q) {
  return q == SX_SHADOWS_HIGH ? "high" : q == SX_SHADOWS_LOW ? "low" : "off";
}

sx_shadow_budget sx_shadow_budget_for(int quality, int nviews) {
  sx_shadow_budget b;
  memset(&b, 0, sizeof b);
  b.quality = quality;
  b.max_lights = quality == SX_SHADOWS_HIGH ? SX_MAX_ACTIVE_LIGHTS : 8;
  if (quality == SX_SHADOWS_HIGH) {
    b.atlas = 1024; /* the screen is 480 x 270: chunky shadows suit it, and fill is the cost */
    b.cascades = 2;
    b.spots = 2;
    b.omni = 3;
    b.radius[0] = 24.0f;
    b.radius[1] = 150.0f;
  } else if (quality == SX_SHADOWS_LOW) {
    b.atlas = 512;
    b.cascades = 1;
    b.spots = 1;
    b.omni = 1;
    b.radius[0] = 60.0f;
    b.radius[1] = 60.0f;
  }
  /* a split screen shades every view: two views share the budget, three or four get the minimum */
  if (nviews >= 3) {
    b.max_lights = 8;
    if (b.cascades > 1) b.cascades = 1;
    if (b.spots > 1) b.spots = 1;
    if (b.omni > 1) b.omni = 1;
    if (b.cascades) b.radius[0] = 60.0f;
  } else if (nviews == 2 && b.omni > 2) {
    b.omni = 2;
  }
  return b;
}

float sx_light_reach(const sx_light *l, const float p[3]) {
  float d[3], d2, x, w;
  if (l->kind == SX_LIGHT_SUN) return l->intensity;
  d[0] = p[0] - l->pos[0];
  d[1] = p[1] - l->pos[1];
  d[2] = p[2] - l->pos[2];
  d2 = dot3(d, d);
  x = d2 / (l->range * l->range);
  if (x >= 1.0f) return 0.0f;
  w = 1.0f - x * x;
  return l->intensity * w * w / (d2 > 0.25f ? d2 : 0.25f);
}

static float lum(const float c[3]) {
  float m = c[0] > c[1] ? c[0] : c[1];
  return m > c[2] ? m : c[2];
}

static float score_of(const sx_light *l, const float cam[3]) {
  float d[3], dist, s;
  if (l->kind == SX_LIGHT_SUN) return 1e30f; /* a sun lights everything: always first */
  d[0] = cam[0] - l->pos[0];
  d[1] = cam[1] - l->pos[1];
  d[2] = cam[2] - l->pos[2];
  dist = (float)sx_sqrt((double)dot3(d, d));
  if (dist - l->range > SX_LIGHT_REACH) return 0.0f;
  /* how bright the light is near the eye: inside its range by the inverse square, outside it the
     light still shows on what it lights, so it counts as if the eye stood at the edge, fading off */
  if (dist < 1.0f) dist = 1.0f;
  s = l->intensity * lum(l->color) * l->priority / (dist * dist);
  if (dist > l->range) s *= 1.0f - (dist - l->range) / (SX_LIGHT_REACH + 1.0f);
  return s;
}

void sx_cube_face_basis(int face, float fwd[3], float right[3], float up[3]) {
  static const float F[6][3] = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}};
  static const float R[6][3] = {{0, 0, 1}, {0, 0, -1}, {1, 0, 0}, {1, 0, 0}, {-1, 0, 0}, {1, 0, 0}};
  static const float U[6][3] = {{0, 1, 0}, {0, 1, 0}, {0, 0, 1}, {0, 0, -1}, {0, 1, 0}, {0, 1, 0}};
  if (face < 0 || face > 5) face = 0;
  memcpy(fwd, F[face], sizeof F[0]);
  memcpy(right, R[face], sizeof R[0]);
  memcpy(up, U[face], sizeof U[0]);
}

static void view_from_basis(float m[16], const float eye[3], const float f[3], const float r[3], const float u[3]) {
  int i;
  sx_mat4_identity(m);
  for (i = 0; i < 3; i++) {
    m[i * 4 + 0] = r[i];
    m[i * 4 + 1] = u[i];
    m[i * 4 + 2] = -f[i];
  }
  m[12] = -dot3(r, eye);
  m[13] = -dot3(u, eye);
  m[14] = dot3(f, eye);
}

void sx_cube_face_view(const float pos[3], int face, float m[16]) {
  float f[3], r[3], u[3];
  sx_cube_face_basis(face, f, r, u);
  view_from_basis(m, pos, f, r, u);
}

void sx_mat4_look(float m[16], const float eye[3], const float fwd[3], const float up_hint[3]) {
  float f[3], r[3], u[3], h[3];
  memcpy(f, fwd, sizeof f);
  norm3(f);
  memcpy(h, up_hint, sizeof h);
  cross3(r, f, h);
  if (dot3(r, r) < 1e-8f) { /* looking along the hint: any perpendicular will do */
    h[0] = 1;
    h[1] = h[2] = 0;
    if (f[0] > 0.9f || f[0] < -0.9f) {
      h[0] = 0;
      h[2] = 1;
    }
    cross3(r, f, h);
  }
  norm3(r);
  cross3(u, r, f);
  view_from_basis(m, eye, f, r, u);
}

void sx_shadow_face_rect(const float block[4], int face, float out[4]) {
  float w = block[2] / 3.0f, h = block[3] / 2.0f;
  out[0] = block[0] + (float)(face % 3) * w;
  out[1] = block[1] + (float)(face / 3) * h;
  out[2] = w;
  out[3] = h;
}

void sx_shadow_sun_mat(const float dir[3], const float c[3], float r, float depth, int res, float out[16]) {
  float view[16], proj[16], f[3], up[3] = {0, 1, 0}, lc[3], texel, eye[3];
  int i;
  f[0] = -dir[0];
  f[1] = -dir[1];
  f[2] = -dir[2];
  norm3(f);
  /* the eye sits on the sun's side of the centre; the map's x/y origin snaps to whole texels so the
     shadow edges do not crawl as the camera moves */
  for (i = 0; i < 3; i++) eye[i] = c[i] - f[i] * depth;
  sx_mat4_look(view, eye, f, up);
  texel = 2.0f * r / (float)(res > 0 ? res : 1);
  lc[0] = view[12];
  lc[1] = view[13];
  lc[2] = view[14];
  view[12] = (float)sx_floor((double)(lc[0] / texel)) * texel;
  view[13] = (float)sx_floor((double)(lc[1] / texel)) * texel;
  memset(proj, 0, sizeof proj);
  proj[0] = 1.0f / r;
  proj[5] = 1.0f / r;
  proj[10] = -2.0f / (2.0f * depth);
  proj[14] = -1.0f; /* near 0, far 2 * depth: z_ndc = -2 z / (2 depth) - 1 */
  proj[15] = 1.0f;
  sx_mat4_mul(out, proj, view);
}

void sx_shadow_spot_mat(const sx_light *l, float out[16]) {
  float view[16], proj[16], up[3] = {0, 1, 0}, s, half;
  s = 1.0f - l->cos_outer * l->cos_outer;
  half = (float)sx_atan2(sx_sqrt((double)(s > 0 ? s : 0)), (double)l->cos_outer);
  half += 0.05f; /* a margin so the cone's edge is inside the map */
  if (half > 1.45f) half = 1.45f;
  sx_mat4_look(view, l->pos, l->dir, up);
  sx_mat4_perspective(proj, half * 2.0f, 1.0f, 0.1f, l->range);
  sx_mat4_mul(out, proj, view);
}

/* an earlier active spot of the same owner, pointing the same way from within SX_SPOT_TWIN m, with a map */
#define SX_SPOT_TWIN 12.0f
static int shared_spot(const sx_lighting *lt, int upto, const sx_light *l) {
  int k;
  for (k = 0; k < upto; k++) {
    const sx_light *o = &lt->lights[lt->active[k]];
    float d[3];
    if (o->kind != SX_LIGHT_SPOT || o->slot < 0 || o->owner != l->owner || dot3(o->dir, l->dir) < 0.99f) continue;
    d[0] = o->pos[0] - l->pos[0];
    d[1] = o->pos[1] - l->pos[1];
    d[2] = o->pos[2] - l->pos[2];
    if (dot3(d, d) <= SX_SPOT_TWIN * SX_SPOT_TWIN) return o->slot;
  }
  return -1;
}

void sx_lighting_select(sx_lighting *lt, const sx_shadow_budget *b, const float cam[3], const float fwd[3]) {
  int i, k, nsun = 0, nspot = 0, nomni = 0;
  unsigned char taken[SX_MAX_LIGHTS];
  const float *focus = lt->has_focus ? lt->focus : cam;
  float f[3];
  memcpy(f, fwd, sizeof f);
  norm3(f);
  lt->nactive = 0;
  lt->cascades = lt->spots = lt->omni = 0;
  lt->atlas = b->atlas;
  memset(taken, 0, sizeof taken);
  for (i = 0; i < lt->nlights; i++) {
    lt->lights[i].score = score_of(&lt->lights[i], focus);
    lt->lights[i].slot = -1;
  }
  /* the strongest first (ties: the first submitted), at most SX_MAX_ACTIVE_LIGHTS */
  while (lt->nactive < (b->max_lights > 0 && b->max_lights < SX_MAX_ACTIVE_LIGHTS ? b->max_lights : SX_MAX_ACTIVE_LIGHTS)) {
    int best = -1;
    for (i = 0; i < lt->nlights; i++)
      if (!taken[i] && lt->lights[i].score > 0.0f && (best < 0 || lt->lights[i].score > lt->lights[best].score)) best = i;
    if (best < 0) break;
    taken[best] = 1;
    lt->active[lt->nactive++] = best;
  }
  /* atlas: sun cascades along the top half, spots below the first cascade, omni blocks of 3x2 faces */
  lt->shadow_rect[0][0] = 0.0f;
  lt->shadow_rect[0][1] = 0.0f;
  lt->shadow_rect[1][0] = 0.5f;
  lt->shadow_rect[1][1] = 0.0f;
  for (k = 0; k < SX_SHADOW_CASCADES; k++) lt->shadow_rect[k][2] = lt->shadow_rect[k][3] = 0.5f;
  for (k = 0; k < SX_SHADOW_SPOTS; k++) {
    float *r = lt->shadow_rect[SX_SHADOW_CASCADES + k];
    r[0] = 0.25f * (float)k;
    r[1] = 0.5f;
    r[2] = r[3] = 0.25f;
  }
  {
    static const float blocks[SX_SHADOW_OMNI][2] = {{0.5f, 0.5f}, {0.5f, 0.75f}, {0.0f, 0.75f}};
    for (k = 0; k < SX_SHADOW_OMNI; k++) {
      float *r = lt->shadow_rect[SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + k];
      r[0] = blocks[k][0];
      r[1] = blocks[k][1];
      r[2] = 0.375f;
      r[3] = 0.25f;
    }
  }
  if (b->atlas <= 0) return;
  for (k = 0; k < lt->nactive; k++) {
    sx_light *l = &lt->lights[lt->active[k]];
    if (!l->shadow) continue;
    if (l->kind == SX_LIGHT_SUN && nsun == 0 && b->cascades > 0) {
      int c;
      nsun = 1;
      lt->cascades = b->cascades;
      l->slot = 0;
      for (c = 0; c < b->cascades; c++) {
        float r = b->radius[c], ctr[3];
        int j;
        for (j = 0; j < 3; j++) ctr[j] = cam[j] + f[j] * r * 0.6f;
        lt->casc_radius[c] = r;
        sx_shadow_sun_mat(l->dir, ctr, r, 1500.0f, b->atlas / 2, lt->shadow_mat[c]);
      }
    } else if (l->kind == SX_LIGHT_SPOT && l->owner && (l->slot = shared_spot(lt, k, l)) >= 0) {
      /* the twin of a pair (a saucer's two headlights) shares its sibling's map */
    } else if (l->kind == SX_LIGHT_SPOT && nspot < b->spots) {
      l->slot = SX_SHADOW_CASCADES + nspot;
      sx_shadow_spot_mat(l, lt->shadow_mat[SX_SHADOW_CASCADES + nspot]);
      nspot++;
    } else if (l->kind == SX_LIGHT_POINT && nomni < b->omni) {
      l->slot = -2; /* gets a block below */
      nomni++;
    }
  }
  lt->spots = nspot;
  lt->omni = nomni;
  /* omni blocks are sticky: a light that had a block last frame keeps it (so a backend may keep the map
     while nothing moved), the rest take the free ones in order */
  {
    int used[SX_SHADOW_OMNI] = {0}, j;
    float keys[SX_SHADOW_OMNI][4];
    for (k = 0; k < lt->nactive; k++) {
      sx_light *l = &lt->lights[lt->active[k]];
      if (l->slot != -2) continue;
      for (j = 0; j < b->omni; j++)
        if (!used[j] && lt->omni_key[j][3] == l->range && lt->omni_key[j][0] == l->pos[0] &&
            lt->omni_key[j][1] == l->pos[1] && lt->omni_key[j][2] == l->pos[2]) {
          used[j] = 1;
          l->slot = SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + j;
          break;
        }
    }
    for (k = 0; k < lt->nactive; k++) {
      sx_light *l = &lt->lights[lt->active[k]];
      if (l->slot != -2) continue;
      for (j = 0; j < b->omni; j++)
        if (!used[j]) {
          used[j] = 1;
          l->slot = SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + j;
          break;
        }
    }
    for (j = 0; j < SX_SHADOW_OMNI; j++) keys[j][0] = keys[j][1] = keys[j][2] = keys[j][3] = -1.0f;
    for (k = 0; k < lt->nactive; k++) {
      const sx_light *l = &lt->lights[lt->active[k]];
      if (l->kind != SX_LIGHT_POINT || l->slot < 0) continue;
      j = l->slot - SX_SHADOW_CASCADES - SX_SHADOW_SPOTS;
      keys[j][0] = l->pos[0];
      keys[j][1] = l->pos[1];
      keys[j][2] = l->pos[2];
      keys[j][3] = l->range;
    }
    memcpy(lt->omni_key, keys, sizeof keys);
  }
}
