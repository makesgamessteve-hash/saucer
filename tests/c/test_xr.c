/* WebXR (OpenSpec add-webxr-cockpit): constant player scale through the
 * XR view pipeline, hand tracking gestures, comfort settings, haptics.
 * Runs on mocked poses: there is no headset in CI. SPDX-License-Identifier: MIT */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "sx_engine.h"
#include "sx_fs.h"
#include "sx_render.h"
#include "sx_touch.h"
#include "sx_xr.h"
#include "test.h"

/* ---- Player scale is constant ---- */

/* world position of an eye from its final view matrix (column-major, rotation + translation) */
static void eye_world(const float m[16], float out[3]) {
  int c;
  for (c = 0; c < 3; c++) out[c] = -(m[c * 4 + 0] * m[12] + m[c * 4 + 1] * m[13] + m[c * 4 + 2] * m[14]);
}

static float col_len(const float m[16], int c) {
  return sqrtf(m[c * 4] * m[c * 4] + m[c * 4 + 1] * m[c * 4 + 1] + m[c * 4 + 2] * m[c * 4 + 2]);
}

/* the mocked pose pipeline: two eyes IPD apart, composed with the cockpit transform of a given
 * saucer config (position and yaw), the way sx_engine_render does for every XR frame */
TEST(xr_scale_is_constant_across_cockpits) {
  sx_xr x;
  /* cockpit transforms of the Villa and the Seat (and a few more poses): the cockpit moves, never scales */
  static const float pos[5][3] = {{0, 0, 0}, {10, 20, 30}, {-400, 5, 1200}, {3.5f, -2, 0.25f}, {1e4f, 100, -1e4f}};
  static const float yaw[5] = {0, 0.7f, 3.0f, -1.9f, 6.0f};
  int i;
  float ref_y = 0;
  sx_xr_init(&x);
  sx_xr_mock_views(&x, 1920, 1080, 0.064f, 90.0f);
  CHECK(x.nviews == 2 && x.views[0].w == 960 && x.views[1].x == 960 && x.views[0].h == 1080);
  for (i = 0; i < 5; i++) {
    sx_camera c;
    float m0[16], m1[16], e0[3], e1[3], d, dx, dy, dz;
    int k;
    memset(&c, 0, sizeof c);
    c.has_matrices = 1;
    c.pos[0] = pos[i][0];
    c.pos[1] = pos[i][1];
    c.pos[2] = pos[i][2];
    c.yaw = yaw[i];
    memcpy(c.view, x.views[0].view, sizeof c.view);
    sx_camera_view(&c, m0);
    memcpy(c.view, x.views[1].view, sizeof c.view);
    sx_camera_view(&c, m1);
    eye_world(m0, e0);
    eye_world(m1, e1);
    dx = e1[0] - e0[0];
    dy = e1[1] - e0[1];
    dz = e1[2] - e0[2];
    d = sqrtf(dx * dx + dy * dy + dz * dz);
    /* the world scale: the eyes stay one IPD apart and every axis keeps unit length */
    CHECK_NEAR(d, 0.064, 2e-3 + 1e-6 * (fabs(pos[i][0]) + fabs(pos[i][2])));
    for (k = 0; k < 3; k++) CHECK_NEAR(col_len(m0, k), 1.0, 1e-5);
    /* the head height over the cockpit's origin does not depend on where (or how big) the cockpit is */
    if (i == 0) ref_y = e0[1] - c.pos[1];
    CHECK_NEAR(e0[1] - c.pos[1], ref_y, 1e-3 + 1e-6 * fabs(pos[i][1]));
    /* the horizon: a level head stays level whatever the cockpit yaw (no roll in the pipeline) */
    CHECK_NEAR(m0[1], 0, 1e-5);
    CHECK_NEAR(m0[5], 1, 1e-5);
  }
}

TEST(xr_mock_views_degenerate_window) {
  sx_xr x;
  sx_xr_init(&x);
  sx_xr_mock_views(&x, 1, 0, 0.06f, 80.0f);
  CHECK(x.nviews == 2 && x.views[0].h == 0 && x.views[1].w == 1);
}

/* ---- Comfort options ---- */

TEST(xr_snap_angle_codes) {
  sx_xr x;
  float out[SX_XR_COUNT];
  static const int deg[4] = {15, 30, 45, 60};
  static const int code[4] = {3, 0, 1, 2}; /* a + 2 b: none = 30, a = 45, b = 60, both = 15 */
  int i;
  sx_xr_init(&x);
  CHECK(x.snap_units == 2 && sx_xr_snap_deg(&x) == 30.0f);
  for (i = 0; i < 4; i++) {
    CHECK(sx_xr_set_snap_deg(&x, (float)deg[i]) == i + 1);
    x.snap_latch = 0;
    x.values[SX_XR_STICK_RX] = 1.0f;
    sx_xr_filter(&x, out);
    CHECK(out[SX_XR_SNAP_R] == 1.0f);
    CHECK((int)out[SX_XR_SNAP_A] + 2 * (int)out[SX_XR_SNAP_B] == code[i]);
    sx_xr_filter(&x, out); /* the bits ride only on the snap tick */
    CHECK(out[SX_XR_SNAP_A] == 0.0f && out[SX_XR_SNAP_B] == 0.0f);
    x.values[SX_XR_STICK_RX] = 0.0f;
    sx_xr_filter(&x, out);
  }
  CHECK(sx_xr_set_snap_deg(&x, 5.0f) == 1 && sx_xr_snap_deg(&x) == 15.0f);
  CHECK(sx_xr_set_snap_deg(&x, 200.0f) == 4 && x.snap_turn_deg == 60.0f);
  CHECK(sx_xr_set_snap_deg(&x, 37.0f) == 2); /* rounds to the nearest 15 */
}

TEST(xr_vignette_and_comfort_text) {
  sx_xr x, y;
  char buf[160];
  int n;
  sx_xr_init(&x);
  sx_xr_set_vignette(&x, 7.0f);
  CHECK(x.vignette == 1.0f);
  sx_xr_set_vignette(&x, -1.0f);
  CHECK(x.vignette == 0.0f);
  sx_xr_set_vignette(&x, nanf(""));
  CHECK(x.vignette == 0.0f);
  x.snap = 0;
  x.pref_mode = 1;
  sx_xr_set_snap_deg(&x, 45.0f);
  sx_xr_set_vignette(&x, 0.75f);
  /* touch-look-speed: the look sensitivity is clamped to 0.5..2 (junk: 1) */
  CHECK(x.look_sens == 1.0f);
  sx_xr_set_look_sens(&x, 9.0f);
  CHECK(x.look_sens == SX_TOUCH_SENS_MAX);
  sx_xr_set_look_sens(&x, 0.1f);
  CHECK(x.look_sens == SX_TOUCH_SENS_MIN);
  sx_xr_set_look_sens(&x, nanf(""));
  CHECK(x.look_sens == 1.0f);
  sx_xr_set_look_sens(&x, 1.5f);
  n = sx_xr_comfort_format(&x, buf, sizeof buf);
  CHECK(n > 0 && strstr(buf, "snap 0") && strstr(buf, "snap_turn 45") && strstr(buf, "vignette 0.75") &&
        strstr(buf, "mode seated") && strstr(buf, "look_sens 1.50"));
  sx_xr_init(&y);
  CHECK(sx_xr_comfort_parse(&y, buf) == 5);
  CHECK(y.snap == 0 && y.snap_units == 3 && y.vignette == 0.75f && y.pref_mode == 1 && y.look_sens == 1.5f);
  /* junk lines, unknown keys and bad modes change nothing */
  CHECK(sx_xr_comfort_parse(&y, "nonsense\nspeed 9\nmode floating\n\n") == 0);
  CHECK(y.pref_mode == 1);
  CHECK(sx_xr_comfort_parse(&y, "mode standing\nsnap 1") == 2 && y.pref_mode == 2 && y.snap == 1);
  sx_xr_init(&x);
  sx_xr_comfort_format(&x, buf, sizeof buf);
  CHECK(strstr(buf, "snap 1") && strstr(buf, "snap_turn 30") && strstr(buf, "vignette 0.50") && strstr(buf, "mode standing"));
}

TEST(xr_comfort_persists_in_the_user_dir) {
  sx_options o;
  sx_engine *e;
  sx_options_default(&o);
  strcpy(o.user_dir, "build/test-tmp/comfort-user");
  o.headless = o.test_mode = o.quiet = 1;
  sx_fs_mkdirs(o.user_dir);
  remove("build/test-tmp/comfort-user/comfort.txt");
  e = sx_engine_create(&o);
  CHECK(e != NULL);
  if (!e) return;
  CHECK(e->xr.snap == 1 && e->xr.snap_units == 2 && !sx_engine_load_comfort(e));
  e->xr.snap = 0;
  sx_xr_set_snap_deg(&e->xr, 60.0f);
  sx_xr_set_vignette(&e->xr, 0.25f);
  sx_xr_set_look_sens(&e->xr, 1.75f);
  e->xr.pref_mode = 1;
  CHECK(sx_engine_save_comfort(e));
  sx_engine_destroy(e);
  /* a new engine in the same user dir starts with the saved settings */
  e = sx_engine_create(&o);
  CHECK(e != NULL);
  if (!e) return;
  CHECK(e->xr.snap == 0 && e->xr.snap_units == 4 && e->xr.vignette == 0.25f && e->xr.pref_mode == 1);
  CHECK(e->xr.look_sens == 1.75f);
  sx_engine_destroy(e);
  remove("build/test-tmp/comfort-user/comfort.txt");
}

/* ---- Controller and hand mapping ---- */

/* an open right hand: tips well away from the wrist, thumb and index apart */
static void open_hand(float j[SX_XR_JOINTS * 3], float ox, float oy, float oz) {
  static const float rel[SX_XR_JOINTS][3] = {{0, 0, 0}, {-0.04f, 0, 0.09f}, {-0.02f, 0, 0.17f},
                                             {0, 0, 0.18f}, {0.02f, 0, 0.17f}, {0.04f, 0, 0.15f}};
  int k;
  for (k = 0; k < SX_XR_JOINTS; k++) {
    j[k * 3] = ox + rel[k][0];
    j[k * 3 + 1] = oy + rel[k][1];
    j[k * 3 + 2] = oz + rel[k][2];
  }
}
static void pinch_pose(float j[SX_XR_JOINTS * 3]) { /* thumb tip meets index tip */
  int i;
  for (i = 0; i < 3; i++) j[SX_XR_J_THUMB * 3 + i] = j[SX_XR_J_INDEX * 3 + i];
  j[SX_XR_J_THUMB * 3] += 0.01f;
}
static void fist_pose(float j[SX_XR_JOINTS * 3]) { /* tips curl to the palm */
  int k, i;
  for (k = SX_XR_J_MIDDLE; k <= SX_XR_J_PINKY; k++)
    for (i = 0; i < 3; i++) j[k * 3 + i] = j[i] + (i == 2 ? 0.05f : 0.0f);
}

TEST(xr_pinch_is_trigger_and_fist_is_grip) {
  sx_xr x;
  float j[SX_XR_JOINTS * 3], out[SX_XR_COUNT];
  sx_xr_init(&x);
  x.head_fwd[2] = 1;
  x.head_pos[1] = 1.6f;
  open_hand(j, 0.4f, 1.2f, 0.3f);
  sx_xr_set_joints(&x, 1, 1, j);
  CHECK(x.hand_ok[1] && x.hands[1][0] == 0.4f && x.hands[1][5] > 0.9f); /* pose: wrist, pointing along +z */
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_TRIGGER_R] == 0 && out[SX_XR_GRIP_R] == 0 && !x.pinch[1] && !x.grab[1]);
  pinch_pose(j);
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.pinch[1] && out[SX_XR_TRIGGER_R] == 1.0f && out[SX_XR_TRIGGER_L] == 0);
  /* hysteresis: a slightly looser pinch still holds, a clearly open one lets go */
  j[SX_XR_J_THUMB * 3] += 0.015f;
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.pinch[1] && out[SX_XR_TRIGGER_R] == 1.0f);
  j[SX_XR_J_THUMB * 3] += 0.05f;
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(!x.pinch[1] && out[SX_XR_TRIGGER_R] == 0);
  /* a fist is the grip, and not also a pinch */
  open_hand(j, 0.4f, 1.2f, 0.3f);
  fist_pose(j);
  pinch_pose(j);
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.grab[1] && !x.pinch[1] && out[SX_XR_GRIP_R] == 1.0f && out[SX_XR_TRIGGER_R] == 0);
  /* the left hand maps to the left controls */
  open_hand(j, -0.4f, 1.2f, 0.3f);
  pinch_pose(j);
  sx_xr_set_joints(&x, 0, 1, j);
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_TRIGGER_L] == 1.0f && x.pinch[0]);
  open_hand(j, -0.4f, 1.2f, 0.3f);
  fist_pose(j);
  sx_xr_set_joints(&x, 0, 1, j);
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_GRIP_L] == 1.0f);
  /* controller values still pass through next to the hands */
  x.values[SX_XR_A] = 1.0f;
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_A] == 1.0f);
  /* losing tracking clears everything */
  sx_xr_set_joints(&x, 1, 0, NULL);
  sx_xr_set_joints(&x, 0, 0, NULL);
  sx_xr_set_joints(&x, 5, 1, j); /* ignored: no such hand */
  sx_xr_filter(&x, out);
  CHECK(!x.hand_ok[1] && !x.grab[0] && out[SX_XR_GRIP_L] == 0 && out[SX_XR_TRIGGER_R] == 0);
  /* a hand with a flat zero pose still gets a pointing direction */
  memset(j, 0, sizeof j);
  sx_xr_set_joints(&x, 1, 1, j);
  CHECK(x.hands[1][5] == 1.0f);
}

TEST(xr_grab_the_lever_by_hand) {
  sx_xr x;
  float j[SX_XR_JOINTS * 3], out[SX_XR_COUNT], lv[3];
  int downs = 0, ups = 0, i;
  sx_xr_init(&x);
  x.head_pos[1] = 1.6f;
  x.head_fwd[2] = 1;
  sx_xr_lever_pos(&x, lv);
  CHECK_NEAR(lv[0], SX_XR_LEVER_X, 1e-5);
  CHECK_NEAR(lv[1], 1.6 + SX_XR_LEVER_Y, 1e-5);
  CHECK_NEAR(lv[2], SX_XR_LEVER_Z, 1e-5);
  /* turned a quarter to the left (forward +x), the handle is carried round with the head */
  x.head_fwd[0] = 1;
  x.head_fwd[2] = 0;
  sx_xr_lever_pos(&x, lv);
  CHECK_NEAR(lv[0], SX_XR_LEVER_Z, 1e-5);
  CHECK_NEAR(lv[2], -SX_XR_LEVER_X, 1e-5);
  x.head_fwd[0] = 0;
  x.head_fwd[2] = 1;
  sx_xr_lever_pos(&x, lv);
  /* a pinch away from the handle is a plain trigger */
  open_hand(j, 0.4f, 1.6f, 0.3f);
  pinch_pose(j);
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.lever_hand < 0 && out[SX_XR_TRIGGER_R] == 1.0f);
  sx_xr_set_joints(&x, 1, 0, NULL);
  /* pinch the handle (the pinch point is the midpoint of thumb and index) */
  open_hand(j, 0, 0, 0);
  pinch_pose(j);
  {
    float dx = lv[0] - (j[SX_XR_J_THUMB * 3] + j[SX_XR_J_INDEX * 3]) / 2;
    float dy = lv[1] - j[SX_XR_J_INDEX * 3 + 1];
    float dz = lv[2] - j[SX_XR_J_INDEX * 3 + 2];
    for (i = 0; i < SX_XR_JOINTS; i++) {
      j[i * 3] += dx;
      j[i * 3 + 1] += dy;
      j[i * 3 + 2] += dz;
    }
  }
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.lever_hand == 1 && out[SX_XR_TRIGGER_R] == 0 && out[SX_XR_LEVER_DOWN] == 0 && out[SX_XR_LEVER_UP] == 0);
  /* a little move is no detent */
  for (i = 0; i < SX_XR_JOINTS; i++) j[i * 3 + 1] -= 0.03f;
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(out[SX_XR_LEVER_DOWN] == 0);
  /* one detent toward "smaller": a Shrink in that tick's frame, once */
  for (i = 0; i < SX_XR_JOINTS; i++) j[i * 3 + 1] -= 0.06f;
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  downs += out[SX_XR_LEVER_DOWN] == 1.0f;
  sx_xr_filter(&x, out); /* the hand stays put: no second detent */
  downs += out[SX_XR_LEVER_DOWN] == 1.0f;
  CHECK(downs == 1 && out[SX_XR_LEVER_UP] == 0);
  /* and back up one detent: Grow */
  for (i = 0; i < SX_XR_JOINTS; i++) j[i * 3 + 1] += 0.09f;
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  ups += out[SX_XR_LEVER_UP] == 1.0f;
  CHECK(ups == 1 && out[SX_XR_LEVER_DOWN] == 0);
  /* letting go releases the handle; losing the hand does too */
  open_hand(j, 0, 1.6f, 0.3f);
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.lever_hand < 0);
  /* the other hand cannot take a handle someone holds, and an unheld lever frees on tracking loss */
  open_hand(j, 0, 0, 0);
  pinch_pose(j);
  {
    float dy = lv[1] - j[SX_XR_J_INDEX * 3 + 1], dz = lv[2] - j[SX_XR_J_INDEX * 3 + 2], dx = lv[0] - j[SX_XR_J_INDEX * 3];
    for (i = 0; i < SX_XR_JOINTS; i++) {
      j[i * 3] += dx;
      j[i * 3 + 1] += dy;
      j[i * 3 + 2] += dz;
    }
  }
  sx_xr_set_joints(&x, 1, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.lever_hand == 1);
  sx_xr_set_joints(&x, 0, 1, j);
  sx_xr_filter(&x, out);
  CHECK(x.lever_hand == 1 && out[SX_XR_TRIGGER_L] == 1.0f);
  sx_xr_set_joints(&x, 1, 0, NULL);
  CHECK(x.lever_hand < 0);
}

/* ---- haptics ---- */

TEST(xr_haptic_pulses) {
  sx_xr x;
  float s = 0;
  int ms = 0;
  sx_xr_init(&x);
  sx_xr_haptic(&x, -1, 0.5f, 40);
  CHECK(x.haptic_total == 1);
  CHECK(sx_xr_haptic_take(&x, 0, &s, &ms) && s == 0.5f && ms == 40);
  CHECK(!sx_xr_haptic_take(&x, 0, &s, &ms)); /* taken: nothing pending */
  sx_xr_haptic(&x, 1, 3.0f, 9000); /* clamped */
  sx_xr_haptic(&x, 1, 0.2f, 10);   /* a weaker, shorter one keeps the stronger */
  CHECK(sx_xr_haptic_take(&x, 1, &s, &ms) && s == 1.0f && ms == 500);
  CHECK(sx_xr_haptic_take(&x, 1, NULL, NULL) == 0);
  sx_xr_haptic(&x, 0, 0.0f, 10); /* silent pulses are dropped */
  sx_xr_haptic(&x, 0, 0.5f, 0);
  CHECK(x.haptic_total == 4 && sx_xr_haptic_take(&x, 0, &s, &ms) && ms == 1);
  CHECK(!sx_xr_haptic_take(&x, 2, &s, &ms) && !sx_xr_haptic_take(&x, -1, &s, &ms));
}
