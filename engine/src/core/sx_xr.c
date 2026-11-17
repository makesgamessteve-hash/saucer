/* SPDX-License-Identifier: MIT */
#include "sx_xr.h"
#include <string.h>

static const char *names[SX_XR_COUNT] = {"trigger_r", "trigger_l", "grip_r",   "grip_l",   "a",
                                         "b",         "x",         "y",        "menu",     "stick_lx",
                                         "stick_ly",  "stick_rx",  "stick_ry", "lever_up", "lever_down",
                                         "snap_l",    "snap_r"};

void sx_xr_init(sx_xr *x) {
  memset(x, 0, sizeof *x);
  x->head_fwd[2] = -1.0f;
  x->snap_turn_deg = 30.0f;
  x->vignette = 0.5f;
  x->snap = 1;
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

void sx_xr_filter(sx_xr *x, float out[SX_XR_COUNT]) {
  int i;
  float rx;
  for (i = 0; i < SX_XR_COUNT; i++) out[i] = x->values[i];
  out[SX_XR_SNAP_L] = out[SX_XR_SNAP_R] = 0.0f;
  if (!x->snap) return;
  rx = x->values[SX_XR_STICK_RX];
  out[SX_XR_STICK_RX] = 0.0f;
  if (x->snap_latch) {
    if (rx < SX_XR_SNAP_OFF && rx > -SX_XR_SNAP_OFF) x->snap_latch = 0;
    return;
  }
  if (rx >= SX_XR_SNAP_ON || rx <= -SX_XR_SNAP_ON) {
    out[rx > 0 ? SX_XR_SNAP_R : SX_XR_SNAP_L] = 1.0f;
    x->snap_latch = 1;
  }
}
