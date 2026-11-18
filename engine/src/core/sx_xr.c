/* SPDX-License-Identifier: MIT */
#include "sx_xr.h"
#include "sx_math.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_render.h"

static const char *names[SX_XR_COUNT] = {"trigger_r", "trigger_l", "grip_r",   "grip_l",   "a",
                                         "b",         "x",         "y",        "menu",     "stick_lx",
                                         "stick_ly",  "stick_rx",  "stick_ry", "lever_up", "lever_down",
                                         "snap_l",    "snap_r",    "snap_a",   "snap_b"};

void sx_xr_init(sx_xr *x) {
  memset(x, 0, sizeof *x);
  x->head_fwd[2] = -1.0f;
  x->snap_turn_deg = 30.0f;
  x->vignette = 0.5f;
  x->snap = 1;
  x->snap_units = 2;
  x->pref_mode = 2;
  x->lever_hand = -1;
}

int sx_xr_ctl_from_name(const char *name) {
  int i;
  for (i = 0; i < SX_XR_COUNT; i++)
    if (strcmp(names[i], name) == 0) return i;
  return -1;
}

const char *sx_xr_ctl_name(int ctl) { return (ctl >= 0 && ctl < SX_XR_COUNT) ? names[ctl] : "?"; }

int16_t sx_xr_quantize(float v, float range) {
  float s;
  if (!(range > 0.0f) || v != v) return 0;
  s = v / range * 32767.0f;
  if (s >= 32767.0f) return 32767;
  if (s <= -32767.0f) return -32767;
  return (int16_t)(s < 0 ? s - 0.5f : s + 0.5f);
}

float sx_xr_dequantize(int16_t q, float range) { return (float)q / 32767.0f * range; }

void sx_xr_aim(const sx_xr *x, int16_t aim[3]) {
  int i;
  for (i = 0; i < 3; i++) aim[i] = sx_xr_quantize(x->head_fwd[i], 1.0f);
}

static float dist3(const float *a, const float *b) {
  float dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
  return (float)sx_sqrt((double)(dx * dx + dy * dy + dz * dz));
}

void sx_xr_lever_pos(const sx_xr *x, float out[3]) {
  float n = (float)sx_sqrt((double)(x->head_fwd[0] * x->head_fwd[0] + x->head_fwd[2] * x->head_fwd[2]));
  float s = n > 1e-4f ? x->head_fwd[0] / n : 0.0f, c = n > 1e-4f ? x->head_fwd[2] / n : 1.0f;
  /* the yaw rotation of the cockpit frame: a point (px, pz) turns to (px c + pz s, -px s + pz c) */
  out[0] = x->head_pos[0] + SX_XR_LEVER_X * c + SX_XR_LEVER_Z * s;
  out[1] = x->head_pos[1] + SX_XR_LEVER_Y;
  out[2] = x->head_pos[2] - SX_XR_LEVER_X * s + SX_XR_LEVER_Z * c;
}

void sx_xr_set_joints(sx_xr *x, int hand, int ok, const float j[SX_XR_JOINTS * 3]) {
  float d[3], n;
  int i;
  if (hand < 0 || hand > 1) return;
  x->joint_ok[hand] = ok != 0;
  if (!ok) {
    memset(x->joints[hand], 0, sizeof x->joints[hand]);
    x->pinch[hand] = x->grab[hand] = 0;
    if (x->lever_hand == hand) x->lever_hand = -1;
    x->hand_ok[hand] = 0;
    return;
  }
  memcpy(x->joints[hand], j, sizeof x->joints[hand]);
  /* the hand's pose: the wrist, pointing toward the middle finger */
  for (i = 0; i < 3; i++) d[i] = j[SX_XR_J_MIDDLE * 3 + i] - j[SX_XR_J_WRIST * 3 + i];
  n = (float)sx_sqrt((double)(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]));
  for (i = 0; i < 3; i++) {
    x->hands[hand][i] = j[SX_XR_J_WRIST * 3 + i];
    x->hands[hand][3 + i] = n > 1e-5f ? d[i] / n : (i == 2 ? 1.0f : 0.0f);
  }
  x->hand_ok[hand] = 1;
}

/* one tick of gesture tracking: pinch, fist and the lever -> controller-equivalent values */
static void hands_step(sx_xr *x, float out[SX_XR_COUNT]) {
  int h;
  float anchor[3];
  sx_xr_lever_pos(x, anchor);
  for (h = 0; h < 2; h++) {
    const float *j;
    float d, tips, mid[3];
    int i;
    if (!x->joint_ok[h]) continue;
    j = x->joints[h];
    d = dist3(j + SX_XR_J_THUMB * 3, j + SX_XR_J_INDEX * 3);
    tips = (dist3(j + SX_XR_J_MIDDLE * 3, j) + dist3(j + SX_XR_J_RING * 3, j) + dist3(j + SX_XR_J_PINKY * 3, j)) / 3.0f;
    if (x->grab[h]) x->grab[h] = tips < SX_XR_GRAB_OFF;
    else x->grab[h] = tips < SX_XR_GRAB_ON;
    if (x->pinch[h]) x->pinch[h] = d < SX_XR_PINCH_OFF;
    else x->pinch[h] = d < SX_XR_PINCH_ON;
    if (x->grab[h]) x->pinch[h] = 0; /* a fist is a grip, not a pinch */
    for (i = 0; i < 3; i++) mid[i] = (j[SX_XR_J_THUMB * 3 + i] + j[SX_XR_J_INDEX * 3 + i]) / 2.0f;
    if (!x->pinch[h]) {
      if (x->lever_hand == h) x->lever_hand = -1;
    } else if (x->lever_hand < 0 && dist3(mid, anchor) <= SX_XR_LEVER_REACH) {
      x->lever_hand = h;
      x->lever_y0 = mid[1];
    }
    if (x->lever_hand == h) {
      float dy = mid[1] - x->lever_y0;
      if (dy <= -SX_XR_LEVER_DETENT) {
        out[SX_XR_LEVER_DOWN] = 1.0f;
        x->lever_y0 = mid[1];
      } else if (dy >= SX_XR_LEVER_DETENT) {
        out[SX_XR_LEVER_UP] = 1.0f;
        x->lever_y0 = mid[1];
      }
    } else if (x->pinch[h]) {
      out[h ? SX_XR_TRIGGER_R : SX_XR_TRIGGER_L] = 1.0f;
    }
    if (x->grab[h]) out[h ? SX_XR_GRIP_R : SX_XR_GRIP_L] = 1.0f;
  }
}

void sx_xr_filter(sx_xr *x, float out[SX_XR_COUNT]) {
  int i;
  float rx;
  for (i = 0; i < SX_XR_COUNT; i++) out[i] = x->values[i];
  out[SX_XR_SNAP_L] = out[SX_XR_SNAP_R] = out[SX_XR_SNAP_A] = out[SX_XR_SNAP_B] = 0.0f;
  hands_step(x, out);
  if (!x->snap) return;
  rx = x->values[SX_XR_STICK_RX];
  out[SX_XR_STICK_RX] = 0.0f;
  if (x->snap_latch) {
    if (rx < SX_XR_SNAP_OFF && rx > -SX_XR_SNAP_OFF) x->snap_latch = 0;
    return;
  }
  if (rx >= SX_XR_SNAP_ON || rx <= -SX_XR_SNAP_ON) {
    out[rx > 0 ? SX_XR_SNAP_R : SX_XR_SNAP_L] = 1.0f;
    out[SX_XR_SNAP_A] = (float)(((x->snap_units - 2) & 3) & 1);
    out[SX_XR_SNAP_B] = (float)(((x->snap_units - 2) & 3) >> 1);
    x->snap_latch = 1;
  }
}

int sx_xr_set_snap_deg(sx_xr *x, float deg) {
  int u = (int)(deg / (float)SX_XR_SNAP_STEP + 0.5f);
  if (u < 1) u = 1;
  if (u > 4) u = 4;
  x->snap_units = u;
  x->snap_turn_deg = (float)(u * SX_XR_SNAP_STEP);
  return u;
}

float sx_xr_snap_deg(const sx_xr *x) { return (float)(x->snap_units * SX_XR_SNAP_STEP); }

void sx_xr_set_vignette(sx_xr *x, float v) {
  if (!(v >= 0.0f)) v = 0.0f; /* also catches NaN */
  if (v > 1.0f) v = 1.0f;
  x->vignette = v;
}

int sx_xr_comfort_format(const sx_xr *x, char *buf, int cap) {
  return snprintf(buf, (size_t)cap, "snap %d\nsnap_turn %d\nvignette %.2f\nmode %s\n", x->snap ? 1 : 0,
                  x->snap_units * SX_XR_SNAP_STEP, (double)x->vignette, x->pref_mode == 1 ? "seated" : "standing");
}

int sx_xr_comfort_parse(sx_xr *x, const char *text) {
  const char *p = text;
  int n = 0;
  while (*p) {
    char key[32], val[32];
    int len = 0;
    while (p[len] && p[len] != '\n') len++;
    if (sscanf(p, "%31s %31s", key, val) == 2) {
      if (strcmp(key, "snap") == 0) { x->snap = atoi(val) != 0; n++; }
      else if (strcmp(key, "snap_turn") == 0) { sx_xr_set_snap_deg(x, (float)atof(val)); n++; }
      else if (strcmp(key, "vignette") == 0) { sx_xr_set_vignette(x, (float)atof(val)); n++; }
      else if (strcmp(key, "mode") == 0) {
        if (strcmp(val, "seated") == 0) { x->pref_mode = 1; n++; }
        else if (strcmp(val, "standing") == 0) { x->pref_mode = 2; n++; }
      }
    }
    p += len;
    if (*p == '\n') p++;
  }
  return n;
}

void sx_xr_haptic(sx_xr *x, int hand, float strength, int ms) {
  int h;
  if (!(strength > 0.0f)) return;
  if (strength > 1.0f) strength = 1.0f;
  if (ms < 1) ms = 1;
  if (ms > 500) ms = 500;
  for (h = 0; h < 2; h++) {
    if (hand >= 0 && hand != h) continue;
    if (strength > x->haptic_strength[h]) x->haptic_strength[h] = strength;
    if (ms > x->haptic_ms[h]) x->haptic_ms[h] = ms;
  }
  x->haptic_total++;
}

int sx_xr_haptic_take(sx_xr *x, int hand, float *strength, int *ms) {
  if (hand < 0 || hand > 1 || x->haptic_strength[hand] <= 0.0f) return 0;
  if (strength) *strength = x->haptic_strength[hand];
  if (ms) *ms = x->haptic_ms[hand];
  x->haptic_strength[hand] = 0.0f;
  x->haptic_ms[hand] = 0;
  return 1;
}

void sx_xr_mock_views(sx_xr *x, int w, int h, float ipd, float fov_deg) {
  int i;
  float aspect = h > 0 ? (float)(w / 2) / (float)h : 1.0f;
  if (w < 2) w = 2;
  x->nviews = 2;
  x->mocked = 1;
  for (i = 0; i < 2; i++) {
    sx_xr_view *v = &x->views[i];
    sx_mat4_identity(v->view);
    v->view[12] = i == 0 ? ipd * 0.5f : -ipd * 0.5f; /* the eyes sit left and right of the head */
    sx_mat4_perspective(v->proj, fov_deg * 3.14159265f / 180.0f, aspect, 0.05f, 4000.0f);
    v->x = i * (w / 2);
    v->y = 0;
    v->w = w / 2;
    v->h = h;
  }
}
