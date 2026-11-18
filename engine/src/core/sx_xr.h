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
  SX_XR_SNAP_A,     /* add-webxr-cockpit: snap angle bit 0 on the snap tick: code = a + 2 b, units = (code + 1) % 4 + 1 (0 = 30 deg, 1 = 45, 2 = 60, 3 = 15) */
  SX_XR_SNAP_B,     /* ... and bit 1 */
  SX_XR_COUNT
} sx_xr_ctl;

#define SX_XR_JOINTS 6
enum { SX_XR_J_WRIST = 0, SX_XR_J_THUMB, SX_XR_J_INDEX, SX_XR_J_MIDDLE, SX_XR_J_RING, SX_XR_J_PINKY };

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
  /* add-webxr-cockpit: comfort settings (client side, saved in comfort.txt),
   * hand tracking and haptics. snap_units: the snap angle in steps of 15
   * degrees (1..4); pref_mode: the reference space the next session asks for
   * (1 seated, 2 standing). joints: wrist, thumb, index, middle, ring and
   * pinky tips (x y z each) in the head's frame, valid when joint_ok. */
  int snap_units, pref_mode;
  float joints[2][SX_XR_JOINTS * 3];
  int joint_ok[2];
  int pinch[2], grab[2]; /* gesture state per hand (with hysteresis) */
  int lever_hand;        /* hand holding the size lever, -1 none */
  float lever_y0;        /* its height when last latched */
  float haptic_strength[2];
  int haptic_ms[2];
  int haptic_total;      /* pulses requested so far (tests, logs) */
  int mocked;            /* test views, not a headset: the windowed loop keeps ticking (screenshots) */
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

/* ---- add-webxr-cockpit: comfort settings ---- */
#define SX_XR_SNAP_STEP 15
/* snap angle in degrees (rounded to 15, 15..60) and the unit count it gives */
int sx_xr_set_snap_deg(sx_xr *x, float deg);
float sx_xr_snap_deg(const sx_xr *x);
void sx_xr_set_vignette(sx_xr *x, float v);
/* comfort.txt text: "snap 1\nsnap_turn 30\nvignette 0.5\nmode standing\n" */
int sx_xr_comfort_format(const sx_xr *x, char *buf, int cap);
int sx_xr_comfort_parse(sx_xr *x, const char *text);

/* ---- hand tracking: pinch = trigger, fist = grip, pinch near the size lever = lever ---- */
#define SX_XR_PINCH_ON 0.025f
#define SX_XR_PINCH_OFF 0.040f
#define SX_XR_GRAB_ON 0.11f
#define SX_XR_GRAB_OFF 0.14f
#define SX_XR_LEVER_REACH 0.12f
#define SX_XR_LEVER_DETENT 0.08f
/* the size lever's handle, head relative: right side, low, in front (engine
 * frame: +z ahead, the player's right is -x) */
#define SX_XR_LEVER_X (-0.30f)
#define SX_XR_LEVER_Y (-0.30f)
#define SX_XR_LEVER_Z 0.30f
/* hand 0 left, 1 right; j = 18 floats in the engine frame. Also gives the hand a pose (wrist, towards the middle finger). */
void sx_xr_set_joints(sx_xr *x, int hand, int ok, const float j[SX_XR_JOINTS * 3]);
/* the lever handle in the same frame as head_pos */
void sx_xr_lever_pos(const sx_xr *x, float out[3]);

/* ---- haptics: hand 0 left, 1 right, -1 both; strength 0..1, ms 1..500 ---- */
void sx_xr_haptic(sx_xr *x, int hand, float strength, int ms);
/* the pending pulse of a hand (clears it): 1 and its values, or 0 */
int sx_xr_haptic_take(sx_xr *x, int hand, float *strength, int *ms);

/* ---- tests and screenshots without a headset: two eyes side by side in a w x h window ---- */
void sx_xr_mock_views(sx_xr *x, int w, int h, float ipd, float fov_deg);
#endif
