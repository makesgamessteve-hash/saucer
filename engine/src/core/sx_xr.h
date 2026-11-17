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
  SX_XR_SNAP_L,     /* add-presentation-packaging: one snap turn to the left (derived from stick_rx) */
  SX_XR_SNAP_R,     /* ... and to the right */
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
  /* add-presentation-packaging: comfort. snap = 1 turns the right stick into
   * snap-turn presses (smooth turning when 0); snap_latch re-arms once the
   * stick returns to the centre. hands: grip poses (pos3 fwd3) in the same
   * frame as head_pos, valid when hand_ok[i]. */
  int snap, snap_latch;
  float hands[2][6];
  int hand_ok[2];
} sx_xr;

void sx_xr_init(sx_xr *x);
int sx_xr_ctl_from_name(const char *name);
const char *sx_xr_ctl_name(int ctl);
/* Quantize v in [-range, range] to int16 (saturating). */
int16_t sx_xr_quantize(float v, float range);
float sx_xr_dequantize(int16_t q, float range);
/* Quantize the head forward vector into a command-frame aim triple. */
void sx_xr_aim(const sx_xr *x, int16_t aim[3]);
/* Comfort filter: the raw controller values the input layer should see.
 * With snap turning on, a right-stick flick past SX_XR_SNAP_ON gives one
 * tick of snap_l / snap_r and the stick's x no longer turns smoothly. */
#define SX_XR_SNAP_ON 0.7f
#define SX_XR_SNAP_OFF 0.3f
void sx_xr_filter(sx_xr *x, float out[SX_XR_COUNT]);
#endif
