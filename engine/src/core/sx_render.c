/* SPDX-License-Identifier: MIT */
#include "sx_render.h"
#include <stdlib.h>
#include <string.h>
#include "stb_image.h"
#include "sx_font8x8.h"
#include "sx_log.h"
#include "sx_math.h"

static void copy_str(char *dst, size_t cap, const char *src) {
  size_t n = strlen(src);
  if (n >= cap) n = cap - 1;
  memcpy(dst, src, n);
  dst[n] = 0;
}

void sx_render_init(sx_render *r) {
  int i;
  memset(r, 0, sizeof *r);
  r->settings.width = 480;
  r->settings.height = 270;
  r->settings.vertex_snap = 1;
  r->settings.dither = 1;
  /* palette 0: built-in neutral fallback (black, white, magenta, grey ramp) */
  copy_str(r->palette_names[0], sizeof r->palette_names[0], "fallback");
  for (i = 0; i < SX_PALETTE_W; i++) {
    unsigned char g = (unsigned char)i;
    r->palettes[0][i][0] = r->palettes[0][i][1] = r->palettes[0][i][2] = g;
    r->palettes[0][i][3] = 255;
  }
  r->palettes[0][0][3] = 0;
  r->palettes[0][1][0] = 255; r->palettes[0][1][1] = 255; r->palettes[0][1][2] = 255;
  r->palettes[0][2][0] = 255; r->palettes[0][2][1] = 0; r->palettes[0][2][2] = 255;
  r->palettes[0][3][0] = 20; r->palettes[0][3][1] = 0; r->palettes[0][3][2] = 20;
  r->npalettes = 1;
  r->palettes_dirty = 1;
  sx_render_error_texture(r);
}

static void view_free(sx_viewport *v) {
  free(v->meshes);
  free(v->bills);
  free(v->ui);
}

void sx_render_free(sx_render *r) {
  int i;
  for (i = 0; i < SX_MAX_TEXTURES; i++) free(r->textures[i].index);
  for (i = 0; i < SX_MAX_MESHES; i++)
    if (r->meshes[i].used) sx_mesh_free(&r->meshes[i].mesh);
  for (i = 0; i < SX_MAX_VIEWPORTS; i++) view_free(&r->views[i]);
  memset(r, 0, sizeof *r);
}

int sx_render_find_texture(const sx_render *r, const char *path) {
  int i;
  for (i = 1; i < SX_MAX_TEXTURES; i++)
    if (r->textures[i].used && strcmp(r->textures[i].path, path) == 0) return i;
  return 0;
}

int sx_render_texture_from_indices(sx_render *r, const char *path, int w, int h, const unsigned char *idx) {
  int i;
  sx_texture *t;
  for (i = 1; i < SX_MAX_TEXTURES; i++)
    if (!r->textures[i].used) break;
  if (i == SX_MAX_TEXTURES || w <= 0 || h <= 0) return 1; /* error texture */
  t = &r->textures[i];
  memset(t, 0, sizeof *t);
  t->used = 1;
  t->w = w;
  t->h = h;
  t->index = (unsigned char *)malloc((size_t)w * (size_t)h);
  memcpy(t->index, idx, (size_t)w * (size_t)h);
  copy_str(t->path, sizeof t->path, path);
  t->dirty = 1;
  return i;
}

int sx_render_error_texture(sx_render *r) {
  unsigned char px[64];
  int x, y;
  if (r->textures[1].used) return 1;
  for (y = 0; y < 8; y++)
    for (x = 0; x < 8; x++) px[y * 8 + x] = (unsigned char)(((x >> 2) ^ (y >> 2)) & 1 ? 2 : 3);
  x = sx_render_texture_from_indices(r, "<error>", 8, 8, px);
  r->textures[x].is_error = 1;
  return x;
}

int sx_render_texture_from_png(sx_render *r, const char *path, const unsigned char *png, int len) {
  int w, h, n, id;
  unsigned char *px;
  if (!png || len <= 0) {
    SX_WARN("missing texture '%s', using error texture", path);
    return 1;
  }
  px = stbi_load_from_memory(png, len, &w, &h, &n, 1);
  if (!px) {
    SX_WARN("cannot decode texture '%s' (%s), using error texture", path, stbi_failure_reason());
    return 1;
  }
  id = sx_render_texture_from_indices(r, path, w, h, px);
  stbi_image_free(px);
  return id;
}

int sx_render_find_palette(const sx_render *r, const char *name) {
  int i;
  for (i = 0; i < r->npalettes; i++)
    if (strcmp(r->palette_names[i], name) == 0) return i;
  return -1;
}

int sx_render_palettes_from_png(sx_render *r, const char *name, const unsigned char *png, int len) {
  int w, h, n, x, y, first = r->npalettes;
  unsigned char *px = png && len > 0 ? stbi_load_from_memory(png, len, &w, &h, &n, 4) : NULL;
  if (!px) {
    SX_WARN("cannot load palette '%s'", name);
    return -1;
  }
  if (w > SX_PALETTE_W) w = SX_PALETTE_W;
  for (y = 0; y < h && r->npalettes < SX_MAX_PALETTES; y++) {
    int p = r->npalettes++;
    memset(r->palettes[p], 0, sizeof r->palettes[p]);
    for (x = 0; x < w; x++) memcpy(r->palettes[p][x], px + 4 * (y * w + x), 4);
    r->palettes[p][0][3] = 0; /* index 0 is always transparent */
    if (y == 0) copy_str(r->palette_names[p], sizeof r->palette_names[p], name);
    else {
      char buf[48];
      size_t k = strlen(name);
      if (k > 28) k = 28;
      memcpy(buf, name, k);
      buf[k] = '#';
      buf[k + 1] = (char)('0' + (y % 10));
      buf[k + 2] = 0;
      copy_str(r->palette_names[p], sizeof r->palette_names[p], buf);
    }
  }
  stbi_image_free(px);
  r->palettes_dirty = 1;
  return first;
}

int sx_render_add_mesh(sx_render *r, sx_mesh *m) {
  int i;
  for (i = 1; i < SX_MAX_MESHES; i++) {
    if (!r->meshes[i].used) {
      r->meshes[i].used = 1;
      r->meshes[i].mesh = *m;
      r->meshes[i].dirty = 1;
      r->meshes[i].gpu = 0;
      sx_mesh_init(m);
      return i;
    }
  }
  sx_mesh_free(m);
  return 0;
}

void sx_render_free_mesh(sx_render *r, int id) {
  if (id <= 0 || id >= SX_MAX_MESHES || !r->meshes[id].used) return;
  sx_mesh_free(&r->meshes[id].mesh);
  r->meshes[id].used = 0;
}

int sx_render_fallback_font(sx_render *r) {
  unsigned char px[128 * 64];
  int c, x, y;
  for (c = 0; c < 128; c++) {
    int gx = (c % 16) * 8, gy = (c / 16) * 8;
    for (y = 0; y < 8; y++)
      for (x = 0; x < 8; x++) px[(gy + y) * 128 + gx + x] = (sx_font8x8[c][y] >> x) & 1 ? 1 : 0;
  }
  return sx_render_texture_from_indices(r, "<font>", 128, 64, px);
}

/* add-wider-dark: two players side by side (vertical split line) */
void sx_viewport_layout_split(int count, int w, int h, int vertical, int out[][4]) {
  int i;
  if (count == 2 && vertical) {
    for (i = 0; i < 2; i++) {
      out[i][0] = i == 0 ? 0 : w / 2;
      out[i][1] = 0;
      out[i][2] = i == 0 ? w / 2 : w - w / 2;
      out[i][3] = h;
    }
    return;
  }
  sx_viewport_layout(count, w, h, out);
}

void sx_viewport_layout(int count, int w, int h, int out[][4]) {
  int i;
  if (count <= 1) {
    out[0][0] = 0; out[0][1] = 0; out[0][2] = w; out[0][3] = h;
    return;
  }
  if (count == 2) {
    for (i = 0; i < 2; i++) {
      out[i][0] = 0;
      out[i][1] = i == 0 ? 0 : h / 2;
      out[i][2] = w;
      out[i][3] = i == 0 ? h / 2 : h - h / 2;
    }
    return;
  }
  if (count > 4) count = 4;
  for (i = 0; i < count; i++) {
    out[i][0] = (i % 2) ? w / 2 : 0;
    out[i][1] = (i / 2) ? h / 2 : 0;
    out[i][2] = (i % 2) ? w - w / 2 : w / 2;
    out[i][3] = (i / 2) ? h - h / 2 : h / 2;
  }
}

void sx_render_begin_frame(sx_render *r, int nviews) {
  int i, rects[SX_MAX_VIEWPORTS][4];
  if (nviews < 1) nviews = 1;
  if (nviews > SX_MAX_VIEWPORTS) nviews = SX_MAX_VIEWPORTS;
  sx_viewport_layout_split(nviews, r->settings.width, r->settings.height, !r->xr && !r->settings.split_horizontal,
                           rects);
  r->nviews = nviews;
  r->frame++;
  for (i = 0; i < nviews; i++) {
    sx_viewport *v = &r->views[i];
    v->x = rects[i][0];
    v->y = rects[i][1];
    v->w = rects[i][2];
    v->h = rects[i][3];
    v->player = i + 1;
    v->nmeshes = v->nbills = v->nui = 0;
    memset(&v->cam, 0, sizeof v->cam);
    v->cam.fov = 1.2f;
    v->cam.znear = 0.1f;
    v->cam.zfar = 4000.0f;
    v->fog_color[0] = v->fog_color[1] = v->fog_color[2] = 0.0f;
    v->fog_density = 0.0f;
    v->clear_color[0] = v->clear_color[1] = v->clear_color[2] = 0.0f;
    v->light_dir[0] = 0.4f;
    v->light_dir[1] = 0.8f;
    v->light_dir[2] = 0.45f;
    v->ambient = 0.35f;
  }
}

#define PUSH(arr, n, cap, T, val)                                                                                      \
  do {                                                                                                                 \
    if ((n) == (cap)) {                                                                                                \
      (cap) = (cap) ? (cap) * 2 : 64;                                                                                  \
      (arr) = (T *)realloc((arr), sizeof(T) * (size_t)(cap));                                                          \
    }                                                                                                                  \
    (arr)[(n)++] = *(val);                                                                                             \
  } while (0)

void sx_view_mesh(sx_viewport *v, const sx_draw_mesh *d) { PUSH(v->meshes, v->nmeshes, v->cap_meshes, sx_draw_mesh, d); }
void sx_view_billboard(sx_viewport *v, const sx_draw_billboard *b) {
  PUSH(v->bills, v->nbills, v->cap_bills, sx_draw_billboard, b);
}
void sx_view_ui(sx_viewport *v, const sx_draw_ui *u) { PUSH(v->ui, v->nui, v->cap_ui, sx_draw_ui, u); }

void sx_mat4_identity(float m[16]) {
  memset(m, 0, sizeof(float) * 16);
  m[0] = m[5] = m[10] = m[15] = 1.0f;
}

void sx_mat4_mul(float out[16], const float a[16], const float b[16]) {
  float t[16];
  int i, j, k;
  for (i = 0; i < 4; i++)
    for (j = 0; j < 4; j++) {
      float s = 0;
      for (k = 0; k < 4; k++) s += a[k * 4 + j] * b[i * 4 + k];
      t[i * 4 + j] = s;
    }
  memcpy(out, t, sizeof t);
}

void sx_mat4_perspective(float m[16], float fovy, float aspect, float zn, float zf) {
  float f = (float)(sx_cos(fovy * 0.5) / sx_sin(fovy * 0.5));
  memset(m, 0, sizeof(float) * 16);
  m[0] = f / aspect;
  m[5] = f;
  m[10] = (zf + zn) / (zn - zf);
  m[11] = -1.0f;
  m[14] = 2.0f * zf * zn / (zn - zf);
}

/* yaw rotates around +Y; yaw 0 keeps +z forward. */
void sx_mat4_model(float m[16], const float pos[3], float yaw, const float scale[3]) {
  float c = (float)sx_cos(yaw), s = (float)sx_sin(yaw);
  sx_mat4_identity(m);
  m[0] = c * scale[0];
  m[2] = -s * scale[0];
  m[5] = scale[1];
  m[8] = s * scale[2];
  m[10] = c * scale[2];
  m[12] = pos[0];
  m[13] = pos[1];
  m[14] = pos[2];
}

void sx_mat4_model_ypr(float m[16], const float pos[3], float yaw, float pitch, float roll, const float scale[3]) {
  float cy = (float)sx_cos(yaw), sy = (float)sx_sin(yaw);
  float cp = (float)sx_cos(pitch), sp = (float)sx_sin(pitch);
  float cr = (float)sx_cos(roll), sr = (float)sx_sin(roll);
  float r[9]; /* row-major rotation R = Ry * Rx * Rz */
  int i, j;
  {
    /* Rx(pitch) lifts +z toward +y; Rz(roll) turns +x toward +y (the right side, -x, dips) */
    float rz[9] = {cr, -sr, 0, sr, cr, 0, 0, 0, 1};
    float rx[9] = {1, 0, 0, 0, cp, sp, 0, -sp, cp};
    float ry[9] = {cy, 0, sy, 0, 1, 0, -sy, 0, cy};
    float t[9];
    for (i = 0; i < 3; i++)
      for (j = 0; j < 3; j++) t[i * 3 + j] = rx[i * 3 + 0] * rz[0 * 3 + j] + rx[i * 3 + 1] * rz[1 * 3 + j] + rx[i * 3 + 2] * rz[2 * 3 + j];
    for (i = 0; i < 3; i++)
      for (j = 0; j < 3; j++) r[i * 3 + j] = ry[i * 3 + 0] * t[0 * 3 + j] + ry[i * 3 + 1] * t[1 * 3 + j] + ry[i * 3 + 2] * t[2 * 3 + j];
  }
  sx_mat4_identity(m);
  /* column-major: column j is the image of local axis j */
  for (j = 0; j < 3; j++)
    for (i = 0; i < 3; i++) m[j * 4 + i] = r[i * 3 + j] * scale[j];
  m[12] = pos[0];
  m[13] = pos[1];
  m[14] = pos[2];
}

void sx_camera_forward(const sx_camera *c, float f[3]) {
  float cp = (float)sx_cos(c->pitch);
  f[0] = (float)sx_sin(c->yaw) * cp;
  f[1] = (float)sx_sin(c->pitch);
  f[2] = (float)sx_cos(c->yaw) * cp;
}

void sx_camera_view(const sx_camera *c, float m[16]) {
  float f[3], rgt[3], up[3], l;
  int i;
  if (c->has_matrices) {
    /* XR: eye view (relative to the cockpit) * inverse(cockpit transform) */
    float inv[16], cy = (float)sx_cos(c->yaw), sy = (float)sx_sin(c->yaw);
    sx_mat4_identity(inv);
    inv[0] = cy;
    inv[2] = sy;
    inv[8] = -sy;
    inv[10] = cy;
    inv[12] = -(cy * c->pos[0] - sy * c->pos[2]);
    inv[13] = -c->pos[1];
    inv[14] = -(sy * c->pos[0] + cy * c->pos[2]);
    sx_mat4_mul(m, c->view, inv);
    return;
  }
  sx_camera_forward(c, f);
  /* right = f x worldUp(0,1,0) */
  rgt[0] = -f[2];
  rgt[1] = 0;
  rgt[2] = f[0];
  l = (float)sx_sqrt((double)(rgt[0] * rgt[0] + rgt[2] * rgt[2]));
  if (l < 1e-6f) {
    rgt[0] = 1;
    rgt[2] = 0;
  } else {
    rgt[0] /= l;
    rgt[2] /= l;
  }
  up[0] = rgt[1] * f[2] - rgt[2] * f[1];
  up[1] = rgt[2] * f[0] - rgt[0] * f[2];
  up[2] = rgt[0] * f[1] - rgt[1] * f[0];
  if (c->roll != 0.0f) {
    /* bank about the view axis: right' = right cos - up sin, up' = up cos + right sin */
    float cr = (float)sx_cos(c->roll), sr = (float)sx_sin(c->roll), r2[3], u2[3];
    for (i = 0; i < 3; i++) {
      r2[i] = rgt[i] * cr - up[i] * sr;
      u2[i] = up[i] * cr + rgt[i] * sr;
    }
    for (i = 0; i < 3; i++) {
      rgt[i] = r2[i];
      up[i] = u2[i];
    }
  }
  sx_mat4_identity(m);
  for (i = 0; i < 3; i++) {
    m[i * 4 + 0] = rgt[i];
    m[i * 4 + 1] = up[i];
    m[i * 4 + 2] = -f[i];
  }
  m[12] = -(rgt[0] * c->pos[0] + rgt[1] * c->pos[1] + rgt[2] * c->pos[2]);
  m[13] = -(up[0] * c->pos[0] + up[1] * c->pos[1] + up[2] * c->pos[2]);
  m[14] = (f[0] * c->pos[0] + f[1] * c->pos[1] + f[2] * c->pos[2]);
}
