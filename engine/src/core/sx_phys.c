/* SPDX-License-Identifier: MIT */
#include "sx_phys.h"
#include <stdlib.h>
#include <string.h>
#include "sx_math.h"

#define SX_PHYS_CELL 32.0
#define SX_PHYS_MAX_CELLS (1 << 21)
#define SX_PHYS_EPS 1e-3

void sx_phys_init(sx_phys *w) { memset(w, 0, sizeof *w); }

void sx_phys_free(sx_phys *w) {
  free(w->boxes);
  free(w->cell_start);
  free(w->cell_ids);
  free(w->stamp);
  memset(w, 0, sizeof *w);
}

void sx_phys_clear(sx_phys *w) {
  w->count = 0;
  w->dirty = 1;
}

int sx_phys_add_box(sx_phys *w, const double min[3], const double max[3], unsigned mask) {
  sx_box *b;
  int i;
  if (w->count == w->cap) {
    w->cap = w->cap ? w->cap * 2 : 64;
    w->boxes = (sx_box *)realloc(w->boxes, sizeof(sx_box) * (size_t)w->cap);
  }
  b = &w->boxes[w->count];
  for (i = 0; i < 3; i++) {
    b->min[i] = min[i] < max[i] ? min[i] : max[i];
    b->max[i] = min[i] < max[i] ? max[i] : min[i];
  }
  b->mask = mask;
  b->used = 1;
  w->dirty = 1;
  return w->count++;
}

void sx_phys_remove(sx_phys *w, int id) {
  if (id >= 0 && id < w->count) w->boxes[id].used = 0;
}

/* ---- broadphase ---- */

static int cell_of(const sx_phys *w, double v, int a) {
  double f = sx_floor((v - w->org[a]) / w->cell);
  if (f < 0) return 0;
  if (f > (double)(w->dims[a] - 1)) return w->dims[a] - 1;
  return (int)f;
}

static void box_cells(const sx_phys *w, const double lo[3], const double hi[3], int c0[3], int c1[3]) {
  int a;
  for (a = 0; a < 3; a++) {
    c0[a] = cell_of(w, lo[a], a);
    c1[a] = cell_of(w, hi[a], a);
  }
}

static void rebuild(sx_phys *w) {
  double lo[3] = {0, 0, 0}, hi[3] = {0, 0, 0};
  int i, a, any = 0, x, y, z;
  long long ncells;
  w->dirty = 0;
  for (i = 0; i < w->count; i++) {
    for (a = 0; a < 3; a++) {
      if (!any || w->boxes[i].min[a] < lo[a]) lo[a] = w->boxes[i].min[a];
      if (!any || w->boxes[i].max[a] > hi[a]) hi[a] = w->boxes[i].max[a];
    }
    any = 1;
  }
  w->cell = SX_PHYS_CELL;
  for (;;) {
    double total = 1.0;
    for (a = 0; a < 3; a++) {
      w->org[a] = lo[a];
      total *= sx_floor((hi[a] - lo[a]) / w->cell) + 1.0;
    }
    if (total <= (double)SX_PHYS_MAX_CELLS) break;
    w->cell *= 2.0;
  }
  ncells = 1;
  for (a = 0; a < 3; a++) {
    w->dims[a] = (int)sx_floor((hi[a] - lo[a]) / w->cell) + 1;
    ncells *= w->dims[a];
  }
  if ((int)ncells + 1 > w->cells_cap) {
    w->cells_cap = (int)ncells + 1;
    w->cell_start = (int *)realloc(w->cell_start, sizeof(int) * (size_t)w->cells_cap);
  }
  memset(w->cell_start, 0, sizeof(int) * (size_t)(ncells + 1));
  /* count, prefix-sum, fill (boxes in id order inside every cell) */
  for (i = 0; i < w->count; i++) {
    int c0[3], c1[3];
    box_cells(w, w->boxes[i].min, w->boxes[i].max, c0, c1);
    for (z = c0[2]; z <= c1[2]; z++)
      for (y = c0[1]; y <= c1[1]; y++)
        for (x = c0[0]; x <= c1[0]; x++) w->cell_start[((z * w->dims[1]) + y) * w->dims[0] + x + 1]++;
  }
  for (i = 0; i < (int)ncells; i++) w->cell_start[i + 1] += w->cell_start[i];
  if (w->cell_start[ncells] > w->ids_cap) {
    w->ids_cap = w->cell_start[ncells];
    w->cell_ids = (int *)realloc(w->cell_ids, sizeof(int) * (size_t)w->ids_cap);
  }
  {
    int *fill = (int *)malloc(sizeof(int) * (size_t)ncells);
    memcpy(fill, w->cell_start, sizeof(int) * (size_t)ncells);
    for (i = 0; i < w->count; i++) {
      int c0[3], c1[3];
      box_cells(w, w->boxes[i].min, w->boxes[i].max, c0, c1);
      for (z = c0[2]; z <= c1[2]; z++)
        for (y = c0[1]; y <= c1[1]; y++)
          for (x = c0[0]; x <= c1[0]; x++) w->cell_ids[fill[((z * w->dims[1]) + y) * w->dims[0] + x]++] = i;
    }
    free(fill);
  }
  if (w->count > w->stamp_cap) {
    w->stamp_cap = w->cap;
    w->stamp = (unsigned *)realloc(w->stamp, sizeof(unsigned) * (size_t)w->stamp_cap);
  }
  memset(w->stamp, 0, sizeof(unsigned) * (size_t)w->stamp_cap);
  w->stamp_id = 0;
}

/* The broadphase is a cache: queries take a const world and refresh it. */
static sx_phys *ready(const sx_phys *cw) {
  sx_phys *w = (sx_phys *)cw;
  if (w->dirty) rebuild(w);
  return w;
}

double sx_phys_cell_size(sx_phys *w) { return ready(w)->cell; }

/* calls fn(box) for every candidate box once; stops when fn returns nonzero */
typedef int (*visit_fn)(void *ud, int box);
static int visit(const sx_phys *cw, const double lo[3], const double hi[3], visit_fn fn, void *ud) {
  sx_phys *w = ready(cw);
  double qlo[3], qhi[3];
  int c0[3], c1[3], x, y, z, a, k;
  if (w->count == 0) return 0;
  for (a = 0; a < 3; a++) {
    qlo[a] = lo[a] - SX_PHYS_EPS;
    qhi[a] = hi[a] + SX_PHYS_EPS;
  }
  box_cells(w, qlo, qhi, c0, c1);
  if (++w->stamp_id == 0) {
    memset(w->stamp, 0, sizeof(unsigned) * (size_t)w->stamp_cap);
    w->stamp_id = 1;
  }
  for (z = c0[2]; z <= c1[2]; z++)
    for (y = c0[1]; y <= c1[1]; y++)
      for (x = c0[0]; x <= c1[0]; x++) {
        int c = ((z * w->dims[1]) + y) * w->dims[0] + x;
        for (k = w->cell_start[c]; k < w->cell_start[c + 1]; k++) {
          int i = w->cell_ids[k];
          if (w->stamp[i] == w->stamp_id) continue;
          w->stamp[i] = w->stamp_id;
          if (fn(ud, i)) return 1;
        }
      }
  return 0;
}

/* ---- queries ---- */

static int box_overlap(const sx_box *b, const double lo[3], const double hi[3]) {
  return lo[0] < b->max[0] && hi[0] > b->min[0] && lo[1] < b->max[1] && hi[1] > b->min[1] && lo[2] < b->max[2] &&
         hi[2] > b->min[2];
}

typedef struct {
  const sx_phys *w;
  const double *lo, *hi;
  unsigned mask;
} overlap_q;

static int overlap_visit(void *ud, int i) {
  overlap_q *q = (overlap_q *)ud;
  const sx_box *b = &q->w->boxes[i];
  return b->used && (b->mask & q->mask) && box_overlap(b, q->lo, q->hi);
}

int sx_phys_overlaps(const sx_phys *w, const double pos[3], double r, double hh, double margin, unsigned mask) {
  double lo[3], hi[3];
  overlap_q q;
  lo[0] = pos[0] - r - margin;
  hi[0] = pos[0] + r + margin;
  lo[1] = pos[1] - hh - margin;
  hi[1] = pos[1] + hh + margin;
  lo[2] = pos[2] - r - margin;
  hi[2] = pos[2] + r + margin;
  q.w = w;
  q.lo = lo;
  q.hi = hi;
  q.mask = mask;
  return visit(w, lo, hi, overlap_visit, &q);
}

int sx_phys_move(const sx_phys *w, double pos[3], double r, double hh, const double delta[3], unsigned mask) {
  static const int order[3] = {1, 0, 2};
  double len = sx_sqrt(delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2]);
  double step_len = r < hh ? r : hh;
  int steps, s, k, blocked[3] = {0, 0, 0};
  if (step_len < 0.05) step_len = 0.05;
  steps = (int)(len / step_len) + 1;
  if (steps > 256) steps = 256;
  for (s = 0; s < steps; s++) {
    for (k = 0; k < 3; k++) {
      int ax = order[k];
      double old = pos[ax];
      if (blocked[ax]) continue;
      pos[ax] += delta[ax] / (double)steps;
      if (sx_phys_overlaps(w, pos, r, hh, 0.0, mask)) {
        pos[ax] = old;
        blocked[ax] = 1;
      }
    }
  }
  return blocked[0] + blocked[1] + blocked[2];
}

typedef struct {
  const sx_phys *w;
  const double *o, *dir;
  double maxd;
  unsigned mask;
  sx_hit best;
} ray_q;

static int ray_visit(void *ud, int i) {
  ray_q *q = (ray_q *)ud;
  const sx_box *b = &q->w->boxes[i];
  double tmin = 0.0, tmax = q->maxd;
  int a, nax = -1, nsign = 0;
  if (!b->used || !(b->mask & q->mask)) return 0;
  for (a = 0; a < 3; a++) {
    if (q->dir[a] == 0.0) {
      if (q->o[a] < b->min[a] || q->o[a] > b->max[a]) return 0;
    } else {
      double t1 = (b->min[a] - q->o[a]) / q->dir[a];
      double t2 = (b->max[a] - q->o[a]) / q->dir[a];
      int sign = -1;
      if (t1 > t2) {
        double t = t1;
        t1 = t2;
        t2 = t;
        sign = 1;
      }
      if (t1 > tmin) {
        tmin = t1;
        nax = a;
        nsign = sign;
      }
      if (t2 < tmax) tmax = t2;
      if (tmin > tmax) return 0;
    }
  }
  /* nearest hit wins; equal distances go to the lowest box id (as a scan in id order would) */
  if (tmin < q->best.t || (q->best.hit && tmin == q->best.t && i < q->best.box)) {
    q->best.hit = 1;
    q->best.box = i;
    q->best.t = tmin;
    memset(q->best.normal, 0, sizeof q->best.normal);
    if (nax >= 0) q->best.normal[nax] = (double)nsign;
  }
  return 0;
}

sx_hit sx_phys_raycast(const sx_phys *w, const double o[3], const double dir[3], double maxd, unsigned mask) {
  ray_q q;
  double lo[3], hi[3];
  int a;
  memset(&q, 0, sizeof q);
  q.w = w;
  q.o = o;
  q.dir = dir;
  q.maxd = maxd;
  q.mask = mask;
  q.best.box = -1;
  q.best.t = maxd;
  for (a = 0; a < 3; a++) {
    double e = o[a] + dir[a] * maxd;
    lo[a] = o[a] < e ? o[a] : e;
    hi[a] = o[a] < e ? e : o[a];
  }
  visit(w, lo, hi, ray_visit, &q);
  return q.best;
}

int sx_phys_cone_visible(const sx_phys *w, const double o[3], const double dir[3], double cos_half,
                         double range, const double target[3], unsigned mask) {
  double d[3], dl, fl, dot;
  sx_hit h;
  int i;
  for (i = 0; i < 3; i++) d[i] = target[i] - o[i];
  dl = sx_sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
  fl = sx_sqrt(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
  if (dl > range || fl == 0.0) return 0;
  if (dl == 0.0) return 1;
  dot = (d[0] * dir[0] + d[1] * dir[1] + d[2] * dir[2]) / (dl * fl);
  if (dot < cos_half) return 0;
  h = sx_phys_raycast(w, o, d, 1.0, mask);
  return !h.hit;
}
