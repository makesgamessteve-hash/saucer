/* add-realistic-lighting: the per-viewport light list. Lua submits suns, point lights and spots each
 * frame (view:light); the core picks the ones that matter for this view (the brightest at the eye,
 * inverse-square), hands the shadow budget (quality preset, fewer per view in a split screen) to the
 * most important shadow casters and builds their shadow matrices and depth-atlas tiles. The GL
 * backend only consumes the result, so all of this is unit tested without a GPU.
 * SPDX-License-Identifier: MIT */
#ifndef SX_LIGHT_H
#define SX_LIGHT_H

#define SX_MAX_LIGHTS 96        /* submitted per viewport per frame */
#define SX_MAX_ACTIVE_LIGHTS 16 /* shaded per pixel */
#define SX_SHADOW_CASCADES 2    /* sun: fitted orthographic maps round the eye */
#define SX_SHADOW_SPOTS 2       /* spot lights (headlights) */
#define SX_SHADOW_OMNI 3        /* point lights: six faces each in the atlas */
#define SX_SHADOW_RECTS (SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + SX_SHADOW_OMNI)
#define SX_LIGHT_SOFT 0.0625f   /* falloff I / (d^2 + (range / 4)^2): inverse-square with a soft source */
#define SX_LIGHT_REACH 150.0f   /* a light this far beyond its range from the eye is dropped */

enum { SX_LIGHT_SUN = 0, SX_LIGHT_POINT = 1, SX_LIGHT_SPOT = 2 };
enum { SX_SHADOWS_OFF = 0, SX_SHADOWS_LOW = 1, SX_SHADOWS_HIGH = 2 };

typedef struct sx_light {
  int kind;
  float pos[3];      /* point / spot */
  float dir[3];      /* sun: toward the sun; spot: where the cone points (unit) */
  float color[3];    /* linear */
  float intensity;   /* sun: irradiance scale; point/spot: intensity at 1 m (inverse-square) */
  float range;       /* point / spot: the light fades to 0 here */
  float cos_inner, cos_outer; /* spot cone */
  int shadow;        /* wants to cast shadows */
  int owner;         /* the shadow pass skips meshes of the same owner (a saucer's own hull) */
  float priority;    /* importance scale (1 = plain) */
  /* filled by sx_lighting_select */
  float score;
  int slot; /* -1 none; sun 0 (cascades 0..n-1), spot SX_SHADOW_CASCADES + k, point SX_SHADOW_CASCADES + SX_SHADOW_SPOTS + k */
} sx_light;

typedef struct sx_shadow_budget {
  int quality;  /* SX_SHADOWS_* */
  int atlas;    /* depth atlas size (px, square); 0 = no shadows */
  int cascades; /* sun cascades */
  int spots, omni;
  int max_lights; /* shaded per pixel (<= SX_MAX_ACTIVE_LIGHTS) */
  float radius[SX_SHADOW_CASCADES]; /* sun cascade half-sizes (m) */
} sx_shadow_budget;

typedef struct sx_lighting {
  int on;            /* 0: the legacy single directional light + ambient (view:fog) */
  float ambient[3];  /* additive floor (space is dark: keep it tiny) */
  float exposure;
  float focus[3];
  int has_focus;
  sx_light lights[SX_MAX_LIGHTS];
  int nlights, dropped;
  /* selection */
  int active[SX_MAX_ACTIVE_LIGHTS];
  int nactive;
  int cascades, spots, omni; /* shadow maps in use */
  float casc_radius[SX_SHADOW_CASCADES];
  float shadow_mat[SX_SHADOW_CASCADES + SX_SHADOW_SPOTS][16]; /* world -> clip */
  float shadow_rect[SX_SHADOW_RECTS][4];                      /* atlas uv x, y, w, h (omni: the 3x2 block) */
  int atlas;
  float omni_key[SX_SHADOW_OMNI][4]; /* the light (pos, range) each omni block holds; kept across frames */
} sx_lighting;

void sx_lighting_reset(sx_lighting *lt);
/* -> index, or -1 when the list is full (counted in lt->dropped) */
int sx_lighting_add(sx_lighting *lt, const sx_light *l);
void sx_light_defaults(sx_light *l, int kind);
int sx_shadow_quality_from_name(const char *name); /* -1 unknown */
const char *sx_shadow_quality_name(int q);
sx_shadow_budget sx_shadow_budget_for(int quality, int nviews);
/* Picks the active lights for an eye at cam (looking along fwd) and assigns the shadow budget. */
void sx_lighting_select(sx_lighting *lt, const sx_shadow_budget *b, const float cam[3], const float fwd[3]);
/* Brightness of light l at point p (inverse-square with a smooth range window; sun: intensity). */
float sx_light_reach(const sx_light *l, const float p[3]);

/* Cube faces of an omni shadow: forward / right / up of face f (0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z). */
void sx_cube_face_basis(int face, float fwd[3], float right[3], float up[3]);
void sx_cube_face_view(const float pos[3], int face, float m[16]);
void sx_shadow_face_rect(const float block[4], int face, float out[4]);
/* world -> clip of a sun cascade centred on c, half-size r, snapped to whole texels of a res-px map */
void sx_shadow_sun_mat(const float dir[3], const float c[3], float r, float depth, int res, float out[16]);
void sx_shadow_spot_mat(const sx_light *l, float out[16]);
void sx_mat4_look(float m[16], const float eye[3], const float fwd[3], const float up_hint[3]);
#endif
