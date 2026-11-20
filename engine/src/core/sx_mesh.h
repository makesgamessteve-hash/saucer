/* Primitive mesh builder: boxes, wedges, cylinders, rings, domes, extrusions
 * and star shells with box-projected UVs and flat normals (retro look).
 * Kit modules and hero meshes (saucer sizes, sentries, trader) are built
 * from these in Lua via saucer.mesh.build.
 * SPDX-License-Identifier: MIT */
#ifndef SX_MESH_H
#define SX_MESH_H
#include <stdint.h>

#define SX_VTX_FLOATS 12 /* pos3 normal3 uv2 color3 emissive1 */

typedef struct sx_mesh {
  float *v;      /* SX_VTX_FLOATS per vertex */
  uint32_t *idx; /* triangles */
  int nv, ni, cap_v, cap_i;
  float bmin[3], bmax[3];
} sx_mesh;

typedef struct sx_part_style {
  float color[3];
  float emissive; /* 0..1, unlit glow */
  float uv_scale; /* texels per meter / tile size; default 0.25 (4 m tile) */
} sx_part_style;

void sx_mesh_init(sx_mesh *m);
void sx_mesh_free(sx_mesh *m);
void sx_style_default(sx_part_style *s);
void sx_mesh_box(sx_mesh *m, const float mn[3], const float mx[3], const sx_part_style *s);
/* Box whose top slopes down along +x (dx) to `low` fraction of the height. */
void sx_mesh_wedge(sx_mesh *m, const float mn[3], const float mx[3], float low, const sx_part_style *s);
void sx_mesh_cylinder(sx_mesh *m, const float c[3], float r, float h, int seg, const sx_part_style *s);
/* Cone frustum: bottom radius r0 at c.y, top radius r1 at c.y + h. */
void sx_mesh_frustum(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, const sx_part_style *s);
/* Frustum without end caps (open tube): hull shells you can stand inside. */
void sx_mesh_tube(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, const sx_part_style *s);
/* An open tube with a doorway: the segments within gap_half radians of azimuth gap_at (atan2(x, z)) are left out. */
void sx_mesh_tube_gap(sx_mesh *m, const float c[3], float r0, float r1, float h, int seg, float gap_at, float gap_half,
                      const sx_part_style *s);
void sx_mesh_ring(sx_mesh *m, const float c[3], float rin, float rout, float h, int seg, const sx_part_style *s);
/* Upper hemisphere (scaled ellipsoid) of radius r and height h. */
void sx_mesh_dome(sx_mesh *m, const float c[3], float r, float h, int seg, int rings, const sx_part_style *s);
/* Extrude a CCW polygon (x,z pairs) from y0 to y1. */
void sx_mesh_extrude(sx_mesh *m, const float *xz, int n, float y0, float y1, const sx_part_style *s);
/* Shell of tiny quads around the origin (starfield). */
void sx_mesh_stars(sx_mesh *m, int count, float radius, float size, uint64_t seed);
uint64_t sx_mesh_hash(const sx_mesh *m);
#endif
