/* true-3d-flight: broadphase equivalence, camera bank and yaw/pitch/roll model matrices.
 * SPDX-License-Identifier: MIT */
#include <stdlib.h>
#include "sx_phys.h"
#include "sx_render.h"
#include "sx_rng.h"
#include "test.h"

/* brute force reference: the scan in id order the broadphase replaced */
static int ref_overlaps(const sx_phys *w, const double p[3], double r, double hh) {
  int i;
  for (i = 0; i < w->count; i++) {
    const sx_box *b = &w->boxes[i];
    if (!b->used) continue;
    if (p[0] - r < b->max[0] && p[0] + r > b->min[0] && p[1] - hh < b->max[1] && p[1] + hh > b->min[1] &&
        p[2] - r < b->max[2] && p[2] + r > b->min[2])
      return 1;
  }
  return 0;
}

static double frand(sx_pcg32 *r, double lo, double hi) { return lo + (hi - lo) * (double)sx_pcg32_next(r) / 4294967296.0; }

TEST(phys_broadphase_matches_brute_force) {
  sx_phys w;
  sx_pcg32 r;
  int i, mismatches = 0;
  sx_phys_init(&w);
  sx_pcg32_seed(&r, 7, 3);
  /* a spread-out 3D world: thin slabs, tall shafts, a few far-away boxes */
  for (i = 0; i < 600; i++) {
    double mn[3], mx[3];
    int a;
    for (a = 0; a < 3; a++) {
      mn[a] = frand(&r, -900, 900);
      mx[a] = mn[a] + frand(&r, 0.5, i % 7 == 0 ? 300 : 20);
    }
    sx_phys_add_box(&w, mn, mx, 1);
  }
  sx_phys_remove(&w, 5);
  for (i = 0; i < 3000; i++) {
    double p[3] = {frand(&r, -1000, 1000), frand(&r, -1000, 1000), frand(&r, -1000, 1000)};
    double rr = frand(&r, 0.5, 15), hh = frand(&r, 0.5, 8);
    if (ref_overlaps(&w, p, rr, hh) != sx_phys_overlaps(&w, p, rr, hh, 0, 1)) mismatches++;
  }
  CHECK_EQ_INT(mismatches, 0);
  /* rays: the nearest box id is the same as a full scan */
  for (i = 0; i < 400; i++) {
    double o[3] = {frand(&r, -900, 900), frand(&r, -900, 900), frand(&r, -900, 900)};
    double d[3] = {frand(&r, -1, 1), frand(&r, -1, 1), frand(&r, -1, 1)};
    sx_hit h = sx_phys_raycast(&w, o, d, 400, 1);
    int k, best = -1;
    double bt = 400;
    for (k = 0; k < w.count; k++) {
      sx_phys one;
      sx_hit hk;
      if (!w.boxes[k].used) continue;
      sx_phys_init(&one);
      sx_phys_add_box(&one, w.boxes[k].min, w.boxes[k].max, 1);
      hk = sx_phys_raycast(&one, o, d, 400, 1);
      if (hk.hit && hk.t < bt) {
        bt = hk.t;
        best = k;
      }
      sx_phys_free(&one);
    }
    if (h.box != best) mismatches++;
  }
  CHECK_EQ_INT(mismatches, 0);
  CHECK(sx_phys_cell_size(&w) >= 32.0);
  /* adding a box after queries rebuilds the grid */
  {
    double mn[3] = {5000, 5000, 5000}, mx[3] = {5010, 5010, 5010}, p[3] = {5005, 5005, 5005};
    sx_phys_add_box(&w, mn, mx, 1);
    CHECK(sx_phys_overlaps(&w, p, 1, 1, 0, 1));
    sx_phys_clear(&w);
    CHECK(!sx_phys_overlaps(&w, p, 1, 1, 0, 1));
  }
  sx_phys_free(&w);
}

TEST(phys_broadphase_huge_extent_and_stamp_wrap) {
  sx_phys w;
  double a0[3] = {-1e9, 0, 0}, a1[3] = {-1e9 + 1, 1, 1}, b0[3] = {1e9, 0, 0}, b1[3] = {1e9 + 1, 1, 1};
  double p[3] = {1e9 + 0.5, 0.5, 0.5}, q[3] = {0, 0.5, 0.5};
  sx_phys_init(&w);
  sx_phys_add_box(&w, a0, a1, 1);
  sx_phys_add_box(&w, b0, b1, 1);
  CHECK(sx_phys_overlaps(&w, p, 0.1, 0.1, 0, 1));
  CHECK(!sx_phys_overlaps(&w, q, 0.1, 0.1, 0, 1));
  CHECK(sx_phys_cell_size(&w) > 32.0);
  w.stamp_id = 0xFFFFFFFFu; /* next query wraps the stamp counter */
  CHECK(sx_phys_overlaps(&w, p, 0.1, 0.1, 0, 1));
  sx_phys_free(&w);
}

TEST(phys_remove_trims_the_tail) {
  sx_phys w;
  double a[3] = {0, 0, 0}, b[3] = {1, 1, 1};
  int i0, i1, i2;
  sx_phys_init(&w);
  i0 = sx_phys_add_box(&w, a, b, 1);
  i1 = sx_phys_add_box(&w, a, b, 1);
  i2 = sx_phys_add_box(&w, a, b, 1);
  sx_phys_remove(&w, i1);
  CHECK_EQ_INT(w.count, 3); /* a hole in the middle stays */
  sx_phys_remove(&w, i2);
  CHECK_EQ_INT(w.count, 1); /* the tail and the hole under it go */
  CHECK_EQ_INT(sx_phys_add_box(&w, a, b, 1), 1);
  CHECK(w.boxes[i0].used);
  sx_phys_remove(&w, 0);
  sx_phys_remove(&w, 1);
  CHECK_EQ_INT(w.count, 0);
  sx_phys_remove(&w, 9);
  sx_phys_free(&w);
}

TEST(camera_roll_banks_the_view) {
  sx_camera c;
  float m[16];
  memset(&c, 0, sizeof c);
  sx_camera_view(&c, m);
  /* level: world up maps to view up */
  CHECK_NEAR(m[5], 1, 1e-6);
  c.roll = 1.5707963f; /* banked 90 degrees right: world up now points to screen left... */
  sx_camera_view(&c, m);
  /* view x of world up (column 1 row 0) */
  CHECK_NEAR(m[1 * 4 + 0], -1, 1e-5);
  CHECK_NEAR(m[1 * 4 + 1], 0, 1e-5);
}

TEST(model_matrix_yaw_pitch_roll) {
  float m[16], m2[16];
  float pos[3] = {1, 2, 3}, sc[3] = {1, 2, 3};
  sx_mat4_model_ypr(m, pos, 0.7f, 0, 0, sc);
  sx_mat4_model(m2, pos, 0.7f, sc);
  {
    int i;
    for (i = 0; i < 16; i++) CHECK_NEAR(m[i], m2[i], 1e-6);
  }
  /* pitch up: local +z tips toward +y */
  sx_mat4_model_ypr(m, pos, 0, 0.5f, 0, sc);
  CHECK(m[2 * 4 + 1] > 0);
  /* roll right: local +x (left) rises */
  sx_mat4_model_ypr(m, pos, 0, 0, 0.5f, sc);
  CHECK(m[0 * 4 + 1] > 0);
  CHECK(m[12] == 1 && m[13] == 2 && m[14] == 3);
}
