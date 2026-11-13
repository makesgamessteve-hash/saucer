/* WebXR state shared by the JS glue (platform) and the engine core:
 * session flags, per-eye views, controller values and the pose quantizer
 * that turns head/controller poses into command-frame aim values.
 * SPDX-License-Identifier: MIT */
#ifndef SX_XR_H
#define SX_XR_H
#include <stdint.h>

typedef enum {
  SX_XR_TRIGGER_R = 0,
  SX_XR_TRIGGER_L,
  SX_XR_GRIP_R,
  SX_XR_GRIP_L,
  SX_XR_A,
  SX_XR_B,
  SX_XR_X,
  SX_XR_Y,
  SX_XR_MENU,
  SX_XR_STICK_LX,
  SX_XR_STICK_LY,
  SX_XR_STICK_RX,
  SX_XR_STICK_RY,
  SX_XR_LEVER_UP,   /* size lever pushed to the next detent (grow) */
  SX_XR_LEVER_DOWN, /* size lever pulled (shrink) */
  SX_XR_COUNT
} sx_xr_ctl;

typedef struct sx_xr_view {
  float view[16], proj[16];
  int x, y, w, h;
} sx_xr_view;

typedef struct sx_xr {
  int available;  /* browser reports immersive-vr support */
  int session;    /* 0 none, 1 seated, 2 standing */
  int nviews;
  sx_xr_view views[2];
  int framebuffer; /* GL name of the XR layer framebuffer */
  float head_pos[3], head_fwd[3];
  float values[SX_XR_COUNT];
  float snap_turn_deg;
  float vignette;
} sx_xr;

void sx_xr_init(sx_xr *x);
int sx_xr_ctl_from_name(const char *name);
const char *sx_xr_ctl_name(int ctl);
/* Quantize v in [-range, range] to int16 (saturating). */
int16_t sx_xr_quantize(float v, float range);
float sx_xr_dequantize(int16_t q, float range);
/* Quantize the head forward vector into a command-frame aim triple. */
void sx_xr_aim(const sx_xr *x, int16_t aim[3]);
#endif
