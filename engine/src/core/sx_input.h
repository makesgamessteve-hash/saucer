/* Devices -> player claims -> action map -> quantized command frames.
 * The sim only ever sees sx_cmd frames (also what replays store).
 * SPDX-License-Identifier: MIT */
#ifndef SX_INPUT_H
#define SX_INPUT_H
#include <stdint.h>

#define SX_MAX_PLAYERS 4
#define SX_MAX_ACTIONS 48
#define SX_MAX_BUTTON_ACTIONS 32
#define SX_NUM_AXES 6
#define SX_MAX_BINDINGS 8
#define SX_MAX_PADS 8
#define SX_AXIS_MAX 32767

typedef struct sx_cmd {
  int player; /* 1-based */
  int64_t tick;
  uint32_t buttons; /* held */
  uint32_t edges;   /* went down this tick */
  int16_t axes[SX_NUM_AXES];
  int16_t aim[3];
} sx_cmd;

typedef enum { SX_ACT_BUTTON = 0, SX_ACT_AXIS = 1 } sx_action_kind;

typedef enum {
  SX_SRC_NONE = 0,
  SX_SRC_KEY,       /* code = USB HID scancode */
  SX_SRC_MOUSE_BTN, /* code = 1 left, 2 middle, 3 right */
  SX_SRC_MOUSE_AXIS,/* code = 0 dx, 1 dy, 2 wheel */
  SX_SRC_PAD_BTN,   /* code = SDL_GamepadButton order */
  SX_SRC_PAD_AXIS,  /* code = SDL_GamepadAxis order */
  SX_SRC_TOUCH,     /* code = sx_touch_ctl */
  SX_SRC_XR         /* code = sx_xr_ctl */
} sx_source;

typedef enum {
  SX_DEV_KBM = 0,
  SX_DEV_TOUCH = 1,
  SX_DEV_XR = 2,
  SX_DEV_PAD0 = 3 /* SX_DEV_PAD0 + n */
} sx_device;
#define SX_NUM_DEVICES (SX_DEV_PAD0 + SX_MAX_PADS)

typedef struct sx_binding {
  sx_source src;
  int code;
  float scale; /* sign/scale for axis contributions, threshold for buttons */
} sx_binding;

typedef struct sx_action {
  char name[32];
  sx_action_kind kind;
  int slot; /* bit index (buttons) or axis index */
} sx_action;

/* Raw device state (filled by the platform layer or tests). */
typedef struct sx_raw_input {
  unsigned char keys[512];
  unsigned char mouse_btn[8];
  float mouse_axis[3]; /* accumulated since last frame build */
  unsigned char pad_btn[SX_MAX_PADS][32];
  float pad_axis[SX_MAX_PADS][8]; /* -1..1 */
  int pad_connected[SX_MAX_PADS];
  float touch[32];  /* touch control values, see sx_touch.h */
  float xr[32];     /* xr control values, see sx_xr.h */
  int16_t aim[3];
} sx_raw_input;

typedef struct sx_player_slot {
  int active;
  int claims[SX_NUM_DEVICES]; /* 1 if this device belongs to the player */
  sx_binding bindings[SX_MAX_ACTIONS][SX_MAX_BINDINGS];
  int nbindings[SX_MAX_ACTIONS];
  uint32_t prev_buttons;
  int last_device;
} sx_player_slot;

typedef struct sx_input {
  sx_action actions[SX_MAX_ACTIONS];
  int nactions;
  int nbuttons, naxes;
  sx_player_slot players[SX_MAX_PLAYERS];
  int nplayers;
  int coop_enabled;
  int join_offer[SX_NUM_DEVICES]; /* device is offered "press A to join" */
  int device_used[SX_NUM_DEVICES];
  sx_raw_input raw;
} sx_input;

void sx_input_init(sx_input *in, int local_players);
/* Returns action index or -1 (too many / bad kind). Re-defining returns existing. */
int sx_input_define_action(sx_input *in, const char *name, sx_action_kind kind);
int sx_input_find_action(const sx_input *in, const char *name);
/* Parse "key:Q", "key:W:-1", "mouse:left", "mouse:dx:0.02", "pad:a", "pad:leftx",
 * "pad:lefty:-1", "touch:stick_x", "xr:trigger_r". Returns 1 on success. */
int sx_binding_parse(const char *s, sx_binding *out);
/* Format a binding back to text (buf >= 48). */
void sx_binding_format(const sx_binding *b, char *buf, int cap);
int sx_input_bind(sx_input *in, int player, int action, const char *binding);
void sx_input_clear_bindings(sx_input *in, int player, int action);
/* Device claim management. Returns 1 if claimed. */
int sx_input_claim(sx_input *in, int player, int device);
void sx_input_release(sx_input *in, int device);
int sx_input_owner(const sx_input *in, int device); /* player (1-based) or 0 */
void sx_input_pad_connected(sx_input *in, int pad, int connected);
/* Build one frame per active player and reset per-frame accumulators. */
void sx_input_build(sx_input *in, int64_t tick, sx_cmd *out, int *count);
const char *sx_input_device_mode(const sx_input *in, int player);
int16_t sx_quantize_axis(float v);
/* HID scancode from a key name like "W", "Space", "LCtrl"; -1 when unknown. */
int sx_key_from_name(const char *name);
const char *sx_key_name(int code);
#endif
