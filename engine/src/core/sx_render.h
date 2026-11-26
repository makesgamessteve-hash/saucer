/* Renderer front end: resources (index textures, palette LUT, meshes),
 * per-viewport draw lists filled by Lua on_render, viewport layout math and
 * camera matrices. Backends (GL in platform/, null for headless) consume it.
 * SPDX-License-Identifier: MIT */
#ifndef SX_RENDER_H
#define SX_RENDER_H
#include <stdint.h>
#include "sx_light.h"
#include "sx_material.h"
#include "sx_mesh.h"

#define SX_MAX_VIEWPORTS 4
#define SX_MAX_TEXTURES 256
#define SX_MAX_MESHES 4096
#define SX_PALETTE_W 256
#define SX_MAX_PALETTES 64

typedef struct sx_texture {
  int used, w, h;
  unsigned char *index; /* w*h palette indices; 0 = transparent */
  char path[128];
  int gpu, dirty;
  int is_error;
  int soft; /* a glow: billboards draw it as a smooth additive falloff, not palette texels */
} sx_texture;

typedef struct sx_rmesh {
  int used;
  sx_mesh mesh;
  int gpu, dirty;
} sx_rmesh;

typedef struct sx_camera {
  float pos[3];
  float yaw, pitch; /* radians; yaw 0 looks toward +z */
  float roll;       /* radians about the view axis; > 0 banks right (ignored with XR matrices) */
  float fov;        /* vertical, radians */
  float znear, zfar;
  int has_matrices; /* XR: explicit view/proj */
  float view[16], proj[16];
} sx_camera;

enum { SX_DRAW_SKY = 1, SX_DRAW_GHOST = 2, SX_DRAW_UNLIT = 4, SX_DRAW_NOFOG = 8, SX_DRAW_NOSHADOW = 16 };

typedef struct sx_draw_mesh {
  int mesh, tex, palette;
  float model[16];
  float tint[4];
  int flags;
  int owner; /* add-realistic-lighting: a light of the same owner does not shadow it */
} sx_draw_mesh;

/* replace-bubble-sprites: procedural billboard forms (shader u_form). 0 = unset (a soft
 * texture still draws as a disk); 1 disk, 2 flare, 3 spark, 4 ring, 5 shard, 6 streak,
 * 7 chevron, 8 slit. */
enum {
  SX_BILLFORM_DISK = 1,
  SX_BILLFORM_FLARE = 2,
  SX_BILLFORM_SPARK = 3,
  SX_BILLFORM_RING = 4,
  SX_BILLFORM_SHARD = 5,
  SX_BILLFORM_STREAK = 6,
  SX_BILLFORM_CHEVRON = 7,
  SX_BILLFORM_SLIT = 8
};

typedef struct sx_draw_billboard {
  int tex, palette;
  float pos[3];
  float size[2];
  float tint[4];
  int yaxis; /* 1: rotate around Y only (items), 0: face camera (particles) */
  int sky;   /* add-alien-cities-2: a backdrop sprite, drawn with the sky behind everything */
  int form;  /* replace-bubble-sprites: SX_BILLFORM_* (0: legacy, a soft tex is a disk) */
} sx_draw_billboard;

typedef struct sx_draw_ui {
  int kind; /* 0 rect, 1 text, 2 image, 3 comfort vignette (color[3] = strength) */
  float x, y, w, h;
  float color[4];
  int tex, palette;
  int scale;
  char text[96];
} sx_draw_ui;

typedef struct sx_viewport {
  int x, y, w, h; /* in low-res target pixels */
  int player;
  sx_camera cam;
  float fog_color[3], fog_density;
  float clear_color[3];
  float light_dir[3], ambient;
  sx_lighting lighting; /* add-realistic-lighting: lights of this view (view:light / view:lighting) */
  sx_materials materials; /* add-material-system: material slots of this view (view:materials), reset every frame */
  sx_draw_mesh *meshes;
  int nmeshes, cap_meshes;
  sx_draw_billboard *bills;
  int nbills, cap_bills;
  sx_draw_ui *ui;
  int nui, cap_ui;
} sx_viewport;

typedef struct sx_render_settings {
  int width, height; /* low-res target */
  int vertex_snap, dither, affine;
  int split_horizontal; /* add-wider-dark: 2 players stacked (default side by side) */
  int fill;             /* add-mobile-touch-ux: the platform sizes the target to the window (no letterbox) */
  int shadows;          /* add-realistic-lighting: SX_SHADOWS_OFF / LOW / HIGH */
  int materials;        /* add-material-system: SX_MATERIALS_OFF / LITE / FULL */
} sx_render_settings;

/* add-retro-renderer-basic: the retro effects in force for one view. Vertex snapping and affine
 * texture warping shimmer per eye, so both are forced off when drawing for a headset (the flat
 * settings come back when the session ends); dithering stays as set. */
typedef struct sx_effects {
  int snap, affine, dither;
} sx_effects;

typedef struct sx_render {
  sx_texture textures[SX_MAX_TEXTURES];
  sx_rmesh meshes[SX_MAX_MESHES];
  unsigned char palettes[SX_MAX_PALETTES][SX_PALETTE_W][4];
  char palette_names[SX_MAX_PALETTES][32];
  int npalettes, palettes_dirty;
  sx_viewport views[SX_MAX_VIEWPORTS];
  int nviews;
  sx_render_settings settings;
  int font_tex;
  int xr; /* stereo pair active */
  int frame;
} sx_render;

void sx_render_init(sx_render *r);
sx_effects sx_render_effects(const sx_render_settings *s, int xr);
void sx_render_free(sx_render *r);
/* Load an index map (grayscale PNG where value = palette index) from memory.
 * Returns texture id (>0). On failure returns the error texture id. */
int sx_render_texture_from_png(sx_render *r, const char *path, const unsigned char *png, int len);
/* mark a texture as a soft glow (see sx_texture.soft); returns 0 for a bad id */
int sx_render_texture_soft(sx_render *r, int id, int soft);
int sx_render_texture_from_indices(sx_render *r, const char *path, int w, int h, const unsigned char *idx);
int sx_render_error_texture(sx_render *r);
int sx_render_find_texture(const sx_render *r, const char *path);
/* Palette from a PNG strip (RGBA, width <= 256): each row becomes one palette. */
int sx_render_palettes_from_png(sx_render *r, const char *name, const unsigned char *png, int len);
int sx_render_find_palette(const sx_render *r, const char *name);
int sx_render_add_mesh(sx_render *r, sx_mesh *m); /* takes ownership; id > 0 */
void sx_render_free_mesh(sx_render *r, int id);
/* Build the fallback font texture (8x8 glyphs, 16x8 grid). */
int sx_render_fallback_font(sx_render *r);

/* Viewport layout: count 1, 2 (top/bottom), 3-4 (quad). */
void sx_viewport_layout(int count, int w, int h, int out[][4]);
void sx_viewport_layout_split(int count, int w, int h, int vertical, int out[][4]);
void sx_render_begin_frame(sx_render *r, int nviews);
void sx_view_mesh(sx_viewport *v, const sx_draw_mesh *d);
void sx_view_billboard(sx_viewport *v, const sx_draw_billboard *b);
void sx_view_ui(sx_viewport *v, const sx_draw_ui *u);
/* add-realistic-lighting: pick every view's lights for its camera (after the views were filled) */
void sx_render_select_lights(sx_render *r);

/* Matrices (column-major, GL convention). */
void sx_mat4_identity(float m[16]);
void sx_mat4_mul(float out[16], const float a[16], const float b[16]);
void sx_mat4_perspective(float m[16], float fovy, float aspect, float zn, float zf);
void sx_mat4_model(float m[16], const float pos[3], float yaw, const float scale[3]);
/* Ry(yaw) * Rx(pitch) * Rz(roll) * S: pitch > 0 tips the nose (+z) up, roll > 0 dips the right side (-x). */
void sx_mat4_model_ypr(float m[16], const float pos[3], float yaw, float pitch, float roll, const float scale[3]);
void sx_camera_view(const sx_camera *c, float m[16]);
void sx_camera_forward(const sx_camera *c, float f[3]);

/* Backend interface */
typedef struct sx_render_backend {
  void *user;
  void (*draw)(void *user, sx_render *r);
} sx_render_backend;
#endif
