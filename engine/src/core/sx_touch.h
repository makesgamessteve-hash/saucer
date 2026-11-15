/* Virtual touch controls for mobile web (left stick, right-half look drag,
 * vertical lift slider, buttons). Positions are normalized 0..1 screen space.
 * SPDX-License-Identifier: MIT */
#ifndef SX_TOUCH_H
#define SX_TOUCH_H
#include "sx_input.h"

typedef enum {
  SX_TOUCH_STICK_X = 0,
  SX_TOUCH_STICK_Y,
  SX_TOUCH_LOOK_X,
  SX_TOUCH_LOOK_Y,
  SX_TOUCH_LIFT,
  SX_TOUCH_SHRINK,
  SX_TOUCH_GROW,
  SX_TOUCH_TRACTOR,
  SX_TOUCH_SCAN,
  SX_TOUCH_USE,
  SX_TOUCH_BOOST,
  SX_TOUCH_JAM,
  SX_TOUCH_COUNT
} sx_touch_ctl;

typedef struct sx_touch_widget {
  const char *name;
  int ctl;          /* sx_touch_ctl it drives */
  float x, y, w, h; /* normalized rect */
  int kind;         /* 0 button, 1 stick, 2 slider, 3 look area */
} sx_touch_widget;

#define SX_TOUCH_MAX_FINGERS 10
typedef struct sx_touch {
  int active; /* becomes 1 on first touch event */
  int nwidgets;
  sx_touch_widget widgets[16];
  struct {
    long long id;
    int widget; /* -1 none */
    float sx, sy, x, y;
  } fingers[SX_TOUCH_MAX_FINGERS];
  int nfingers;
  float look_acc[2];
  float values[SX_TOUCH_COUNT];
} sx_touch;

int sx_touch_ctl_from_name(const char *name);
const char *sx_touch_ctl_name(int ctl);
void sx_touch_init(sx_touch *t, float aspect);
void sx_touch_down(sx_touch *t, long long id, float x, float y);
void sx_touch_move(sx_touch *t, long long id, float x, float y);
void sx_touch_up(sx_touch *t, long long id);
/* Write current values into raw->touch and reset look deltas. */
void sx_touch_apply(sx_touch *t, sx_raw_input *raw);
#endif
