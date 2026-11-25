/* add-material-system: material slots for the retro renderer. Each mesh vertex carries a slot (0-7, the 13th
 * float); a view submits up to eight slot records a frame (view:materials) and the shader shades each pixel by
 * its slot's kind: metals by one matcap fetch mapped through a palette-like ramp plus Blinn specular and a
 * Schlick fresnel, crystals by faceted normals, emission, a rim and a fake refraction from the same fetch,
 * organics by wrap lighting, a subsurface tint, a render-time wobble and breathing and a vein pulse. The
 * packing, the matcap baker and the quality presets live here so they are unit tested without a GPU; the GL
 * backend only uploads what pack() returns. Render-only: nothing here is read by the simulation.
 * SPDX-License-Identifier: MIT */
#ifndef SX_MATERIAL_H
#define SX_MATERIAL_H

#define SX_MAT_SLOTS 8   /* slot 0 is plain (today's look) */
#define SX_MAT_VEC4 6    /* vec4s per slot in the shader's u_mat array */
#define SX_MATCAP_SIZE 64
#define SX_MATCAP_LIGHTS 4
#define SX_SKYMAP_W 128  /* add-material-system 5.3: the sector-sky reflection map (equirectangular) */
#define SX_SKYMAP_H 64

enum { SX_MAT_PLAIN = 0, SX_MAT_METAL = 1, SX_MAT_CRYSTAL = 2, SX_MAT_ORGANIC = 3 };
enum { SX_MATERIALS_OFF = 0, SX_MATERIALS_LITE = 1, SX_MATERIALS_FULL = 2 };

typedef struct sx_material {
  int kind;          /* SX_MAT_* */
  float reflect;     /* metal: share of the matcap reflection 0-1; crystal: refraction strength */
  float spec;        /* Blinn exponent (8-96) */
  float f0;          /* Schlick fresnel at normal incidence */
  float emit;        /* crystal glow / organic vein glow 0-1 */
  float wobble[3];   /* organic: amplitude m, period s, spatial scale m */
  float breath;      /* organic: whole-surface breathing amplitude m (period wobble[1] * 3) */
  float pulse;       /* vein pulse Hz (0 none) */
  float wrap;        /* organic wrap diffuse 0-1 */
  float ramp_lo[3];  /* the ramp the reflection / body luminance maps through: dark end */
  float ramp_hi[3];  /* bright end */
  float sss[3];      /* subsurface tint (organic) / rim tint (crystal) */
  float sparkle;     /* crystal: share of facet cells that twinkle 0-1 (lite: off) */
  float brushed;     /* metal: how far the highlight stretches across the brushing 0-1 */
  float ripple;      /* metal: liquid ripple of the normal 0-0.3 (lite: halved) */
} sx_material;

typedef struct sx_materials {
  int on;                       /* a view submitted slots this frame */
  float time;                   /* render-only seconds (never the sim's) */
  int matcap;                   /* texture id of the luminance matcap (0 none) */
  int envmap;                   /* 1: matcap is a sky map (SX_SKYMAP_W x H, equirectangular, world directions) */
  sx_material slot[SX_MAT_SLOTS];
} sx_materials;

void sx_material_default(sx_material *m);
void sx_materials_reset(sx_materials *ms);
int sx_materials_mode_from_name(const char *name); /* -1 unknown */
const char *sx_materials_mode_name(int mode);
/* -> SX_MAT_* or -1 */
int sx_material_kind_from_name(const char *name);
/* Packs the slots for the shader: SX_MAT_SLOTS * SX_MAT_VEC4 vec4s.
 *  [0] kind, reflect, spec, f0     [1] emit, wobble amp, wobble period, wobble scale
 *  [2] ramp_lo rgb, breath         [3] ramp_hi rgb, pulse            [4] sss rgb, wrap
 *  [5] sparkle, brushed, ripple, 0
 * Mode off packs every slot as plain; lite keeps the shading but drops refraction and the wobble's small
 * ripples (breathing stays, at half amplitude), crystal sparkle goes and a liquid metal's ripple halves. Returns the number of non-plain slots. */
int sx_materials_pack(const sx_materials *ms, int mode, float out[SX_MAT_SLOTS * SX_MAT_VEC4 * 4]);
/* Bakes a 64 x 64 luminance matcap (index values 1-255; 0 stays transparent for index textures): the lit
 * sphere seen head-on under up to four key lights given as { dir x, y, z, intensity } (dirs in view space,
 * +z toward the viewer), a dim ambient and a soft Blinn highlight per light, quantized to 16 steps so the ramp
 * lookup stays banded like a palette. Outside the disc the rim value is repeated. */
void sx_matcap_bake(unsigned char *out, const float lights[][4], int nlights, float ambient);
/* Bakes the 128 x 64 luminance sky map a metal outside reflects (index values 1-255, 16 bands like the matcap):
 * the star (a disc and its glow, toward `sun`, scaled by sun_k), the galaxy's band (a soft great circle round the
 * normal band[0..2], strength band[3]), a dim ambient and sparse stars from `seed`. Pixel (x, y) is the world
 * direction at longitude (x + 0.5) / W * 2 pi - pi (atan2(z, x)) and colatitude (y + 0.5) / H * pi (acos(y)), the
 * shader's lookup. Deterministic: no libm (sx_math only). */
void sx_skymap_bake(unsigned char *out, const float sun[3], float sun_k, const float band[4], unsigned seed, float ambient);
/* The wobble the vertex shader applies along the normal at world point p and time t (for tests and the
 * clearance check): amp * sin(2 pi t / period + (p.x + p.y * 0.7 + p.z * 1.3) / scale) + breath * sin(2 pi t /
 * (3 period)). Its magnitude never exceeds amp + breath. */
float sx_material_wobble(const sx_material *m, const float p[3], float t);
#endif
