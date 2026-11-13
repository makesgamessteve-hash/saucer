/* SPDX-License-Identifier: MIT */
#include "sx_phys.h"
#include <stdlib.h>
#include <string.h>
#include "sx_math.h"

void sx_phys_init(sx_phys *w) { memset(w, 0, sizeof *w); }

void sx_phys_free(sx_phys *w) {
  free(w->boxes);
  memset(w, 0, sizeof *w);
}

void sx_phys_clear(sx_phys *w) { w->count = 0; }

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
  return w->count++;
}

void sx_phys_remove(sx_phys *w, int id) {
  if (id >= 0 && id < w->count) w->boxes[id].used = 0;
}

static int box_overlap(const sx_box *b, const double lo[3], const double hi[3]) {
  return lo[0] < b->max[0] && hi[0] > b->min[0] && lo[1] < b->max[1] && hi[1] > b->min[1] && lo[2] < b->max[2] &&
         hi[2] > b->min[2];
}

int sx_phys_overlaps(const sx_phys *w, const double pos[3], double r, double hh, double margin, unsigned mask) {
  double lo[3], hi[3];
  int i;
  lo[0] = pos[0] - r - margin;
  hi[0] = pos[0] + r + margin;
  lo[1] = pos[1] - hh - margin;
  hi[1] = pos[1] + hh + margin;
  lo[2] = pos[2] - r - margin;
  hi[2] = pos[2] + r + margin;
  for (i = 0; i < w->count; i++)
    if (w->boxes[i].used && (w->boxes[i].mask & mask) && box_overlap(&w->boxes[i], lo, hi)) return 1;
  return 0;
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

sx_hit sx_phys_raycast(const sx_phys *w, const double o[3], const double dir[3], double maxd, unsigned mask) {
  sx_hit best;
  int i, a;
  memset(&best, 0, sizeof best);
  best.box = -1;
  best.t = maxd;
  for (i = 0; i < w->count; i++) {
    const sx_box *b = &w->boxes[i];
    double tmin = 0.0, tmax = maxd;
    int nax = -1, nsign = 0, ok = 1;
    if (!b->used || !(b->mask & mask)) continue;
    for (a = 0; a < 3 && ok; a++) {
      if (dir[a] == 0.0) {
        if (o[a] < b->min[a] || o[a] > b->max[a]) ok = 0;
      } else {
        double t1 = (b->min[a] - o[a]) / dir[a];
        double t2 = (b->max[a] - o[a]) / dir[a];
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
        if (tmin > tmax) ok = 0;
      }
    }
    if (ok && tmin < best.t) {
      best.hit = 1;
      best.box = i;
      best.t = tmin;
      memset(best.normal, 0, sizeof best.normal);
      if (nax >= 0) best.normal[nax] = (double)nsign;
    }
  }
  return best;
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
