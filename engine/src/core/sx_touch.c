/* SPDX-License-Identifier: MIT */
#include "sx_touch.h"
#include <string.h>

static const char *ctl_names[SX_TOUCH_COUNT] = {"stick_x", "stick_y", "look_x", "look_y", "lift",  "shrink",
                                                "grow",    "tractor", "scan",   "use",    "boost", "jam"};

int sx_touch_ctl_from_name(const char *name) {
  int i;
  for (i = 0; i < SX_TOUCH_COUNT; i++)
    if (strcmp(ctl_names[i], name) == 0) return i;
  return -1;
}

const char *sx_touch_ctl_name(int ctl) { return (ctl >= 0 && ctl < SX_TOUCH_COUNT) ? ctl_names[ctl] : "?"; }

static void add(sx_touch *t, const char *name, int ctl, float x, float y, float w, float h, int kind) {
  sx_touch_widget *wd = &t->widgets[t->nwidgets++];
  wd->name = name;
  wd->ctl = ctl;
  wd->x = x;
  wd->y = y;
  wd->w = w;
  wd->h = h;
  wd->kind = kind;
}

void sx_touch_init(sx_touch *t, float aspect) {
  float bw;
  memset(t, 0, sizeof *t);
  if (aspect < 0.5f) aspect = 0.5f;
  bw = 0.11f / aspect; /* square-ish buttons, sized by height */
  if (bw < 0.06f) bw = 0.06f;
  add(t, "stick", SX_TOUCH_STICK_X, 0.02f, 0.45f, 0.30f, 0.53f, 1);
  add(t, "lift", SX_TOUCH_LIFT, 0.93f, 0.25f, 0.06f, 0.50f, 2);
  add(t, "shrink", SX_TOUCH_SHRINK, 0.93f - 2.2f * bw, 0.80f, bw, 0.16f, 0);
  add(t, "grow", SX_TOUCH_GROW, 0.93f - 1.1f * bw, 0.80f, bw, 0.16f, 0);
  add(t, "tractor", SX_TOUCH_TRACTOR, 0.93f - 3.3f * bw, 0.80f, bw, 0.16f, 0);
  add(t, "scan", SX_TOUCH_SCAN, 0.93f - 1.1f * bw, 0.62f, bw, 0.16f, 0);
  add(t, "use", SX_TOUCH_USE, 0.93f - 2.2f * bw, 0.62f, bw, 0.16f, 0);
  add(t, "boost", SX_TOUCH_BOOST, 0.34f, 0.80f, bw, 0.16f, 0);
  add(t, "jam", SX_TOUCH_JAM, 0.93f - 3.3f * bw, 0.62f, bw, 0.16f, 0);
  add(t, "look", SX_TOUCH_LOOK_X, 0.5f, 0.0f, 0.5f, 1.0f, 3); /* last: lowest priority */
}

static int hit(const sx_touch *t, float x, float y) {
  int i;
  for (i = 0; i < t->nwidgets; i++) {
    const sx_touch_widget *w = &t->widgets[i];
    if (x >= w->x && x <= w->x + w->w && y >= w->y && y <= w->y + w->h) return i;
  }
  return -1;
}

static int find(const sx_touch *t, long long id) {
  int i;
  for (i = 0; i < t->nfingers; i++)
    if (t->fingers[i].id == id) return i;
  return -1;
}

static float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

static void update_finger(sx_touch *t, int f) {
  int wi = t->fingers[f].widget;
  const sx_touch_widget *w;
  if (wi < 0) return;
  w = &t->widgets[wi];
  if (w->kind == 1) {
    float r = w->h * 0.35f;
    t->values[SX_TOUCH_STICK_X] = clampf((t->fingers[f].x - t->fingers[f].sx) / r, -1, 1);
    t->values[SX_TOUCH_STICK_Y] = clampf((t->fingers[f].y - t->fingers[f].sy) / r, -1, 1);
  } else if (w->kind == 2) {
    t->values[SX_TOUCH_LIFT] = clampf(-((t->fingers[f].y - (w->y + w->h * 0.5f)) / (w->h * 0.5f)), -1, 1);
  } else if (w->kind == 0) {
    t->values[w->ctl] = 1.0f;
  }
}

void sx_touch_down(sx_touch *t, long long id, float x, float y) {
  int f;
  t->active = 1;
  if (find(t, id) >= 0 || t->nfingers >= SX_TOUCH_MAX_FINGERS) return;
  f = t->nfingers++;
  t->fingers[f].id = id;
  t->fingers[f].widget = hit(t, x, y);
  t->fingers[f].sx = t->fingers[f].x = x;
  t->fingers[f].sy = t->fingers[f].y = y;
  update_finger(t, f);
}

void sx_touch_move(sx_touch *t, long long id, float x, float y) {
  int f = find(t, id);
  if (f < 0) return;
  if (t->fingers[f].widget >= 0 && t->widgets[t->fingers[f].widget].kind == 3) {
    t->look_acc[0] += x - t->fingers[f].x;
    t->look_acc[1] += y - t->fingers[f].y;
  }
  t->fingers[f].x = x;
  t->fingers[f].y = y;
  update_finger(t, f);
}

void sx_touch_up(sx_touch *t, long long id) {
  int f = find(t, id), wi;
  if (f < 0) return;
  wi = t->fingers[f].widget;
  if (wi >= 0) {
    const sx_touch_widget *w = &t->widgets[wi];
    if (w->kind == 1) t->values[SX_TOUCH_STICK_X] = t->values[SX_TOUCH_STICK_Y] = 0;
    else if (w->kind == 2) t->values[SX_TOUCH_LIFT] = 0; /* auto-hover: release = hold altitude */
    else if (w->kind == 0) t->values[w->ctl] = 0;
  }
  t->fingers[f] = t->fingers[--t->nfingers];
}

void sx_touch_apply(sx_touch *t, sx_raw_input *raw) {
  int i;
  t->values[SX_TOUCH_LOOK_X] = clampf(t->look_acc[0] * 8.0f, -1, 1);
  t->values[SX_TOUCH_LOOK_Y] = clampf(t->look_acc[1] * 8.0f, -1, 1);
  t->look_acc[0] = t->look_acc[1] = 0;
  for (i = 0; i < SX_TOUCH_COUNT; i++) raw->touch[i] = t->values[i];
}
