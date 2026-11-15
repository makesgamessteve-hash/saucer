/* Static collision world of axis-aligned boxes with kinematic movers.
 * Movers are vertical cylinders approximated by their bounding box.
 * Deterministic: doubles with +,-,*,/ only; boxes are tested in id order.
 * SPDX-License-Identifier: MIT */
#ifndef SX_PHYS_H
#define SX_PHYS_H

typedef struct sx_box {
  double min[3], max[3];
  unsigned mask;
  int used;
} sx_box;

/* Broadphase: a uniform grid of box ids (CSR layout), rebuilt lazily after
 * boxes are added or the world is cleared. Results never depend on it: every
 * candidate still gets the exact test and ties resolve by box id. */
typedef struct sx_phys {
  sx_box *boxes;
  int count, cap;
  int dirty;
  double cell, org[3];
  int dims[3];
  int *cell_start; /* dims[0]*dims[1]*dims[2] + 1 */
  int *cell_ids;
  int cells_cap, ids_cap;
  unsigned *stamp; /* per box: last query that tested it */
  unsigned stamp_id;
  int stamp_cap;
} sx_phys;

typedef struct sx_hit {
  int hit;
  int box;      /* index */
  double t;     /* distance along ray */
  double normal[3];
} sx_hit;

void sx_phys_init(sx_phys *w);
void sx_phys_free(sx_phys *w);
void sx_phys_clear(sx_phys *w);
int sx_phys_add_box(sx_phys *w, const double min[3], const double max[3], unsigned mask);
void sx_phys_remove(sx_phys *w, int id);
/* Does the cylinder (center pos, radius r, half-height hh) + margin overlap a box? */
int sx_phys_overlaps(const sx_phys *w, const double pos[3], double r, double hh, double margin, unsigned mask);
/* Move by delta with per-axis sliding (axis order y, x, z). Writes new pos,
 * returns number of blocked axes. Moves are sub-stepped so thin walls stop
 * fast movers. */
int sx_phys_move(const sx_phys *w, double pos[3], double r, double hh, const double delta[3], unsigned mask);
/* Ray against boxes; dir need not be normalized; maxd in units of |dir|. */
sx_hit sx_phys_raycast(const sx_phys *w, const double o[3], const double dir[3], double maxd, unsigned mask);
/* Is target within the cone (half angle cos) and range of origin, unoccluded? */
int sx_phys_cone_visible(const sx_phys *w, const double o[3], const double dir[3], double cos_half,
                         double range, const double target[3], unsigned mask);
/* Broadphase cell size in use (after the last rebuild), for tests and stats. */
double sx_phys_cell_size(sx_phys *w);
#endif
