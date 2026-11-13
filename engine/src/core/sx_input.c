/* SPDX-License-Identifier: MIT */
#include "sx_input.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sx_touch.h"
#include "sx_xr.h"

typedef struct name_code {
  const char *name;
  int code;
} name_code;

static const name_code key_names[] = {
    {"Return", 40},  {"Escape", 41}, {"Backspace", 42}, {"Tab", 43},    {"Space", 44},  {"Minus", 45},
    {"Equals", 46},  {"F1", 58},     {"F2", 59},        {"F3", 60},     {"F4", 61},     {"F5", 62},
    {"F6", 63},      {"F7", 64},     {"F8", 65},        {"F9", 66},     {"F10", 67},    {"F11", 68},
    {"F12", 69},     {"Right", 79},  {"Left", 80},      {"Down", 81},   {"Up", 82},     {"LCtrl", 224},
    {"LShift", 225}, {"LAlt", 226},  {"RCtrl", 228},    {"RShift", 229}, {"RAlt", 230}, {NULL, 0}};

static const char *pad_buttons[] = {"a",          "b",           "x",            "y",           "back",
                                    "guide",      "start",       "leftstick",    "rightstick",  "leftshoulder",
                                    "rightshoulder", "dpup",     "dpdown",       "dpleft",      "dpright", NULL};
static const char *pad_axes[] = {"leftx", "lefty", "rightx", "righty", "lefttrigger", "righttrigger", NULL};
static const char *mouse_btns[] = {"", "left", "middle", "right", NULL};
static const char *mouse_axes[] = {"dx", "dy", "wheel", NULL};

int sx_key_from_name(const char *name) {
  int i;
  if (!name || !name[0]) return -1;
  if (!name[1]) {
    char c = name[0];
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    if (c >= 'A' && c <= 'Z') return 4 + (c - 'A');
    if (c >= '1' && c <= '9') return 30 + (c - '1');
    if (c == '0') return 39;
    return -1;
  }
  for (i = 0; key_names[i].name; i++)
    if (strcmp(key_names[i].name, name) == 0) return key_names[i].code;
  return -1;
}

const char *sx_key_name(int code) {
  static char buf[2];
  int i;
  if (code >= 4 && code <= 29) {
    buf[0] = (char)('A' + code - 4);
    buf[1] = 0;
    return buf;
  }
  if (code >= 30 && code <= 38) {
    buf[0] = (char)('1' + code - 30);
    buf[1] = 0;
    return buf;
  }
  if (code == 39) return "0";
  for (i = 0; key_names[i].name; i++)
    if (key_names[i].code == code) return key_names[i].name;
  return "?";
}

static int index_of(const char *const *list, const char *name) {
  int i;
  for (i = 0; list[i]; i++)
    if (strcmp(list[i], name) == 0) return i;
  return -1;
}

void sx_input_init(sx_input *in, int local_players) {
  int p;
  memset(in, 0, sizeof *in);
  if (local_players < 1) local_players = 1;
  if (local_players > SX_MAX_PLAYERS) local_players = SX_MAX_PLAYERS;
  in->nplayers = local_players;
  for (p = 0; p < local_players; p++) in->players[p].active = 1;
  in->players[0].claims[SX_DEV_KBM] = 1;
  in->players[0].claims[SX_DEV_TOUCH] = 1;
  in->players[0].claims[SX_DEV_XR] = 1;
}

int sx_input_find_action(const sx_input *in, const char *name) {
  int i;
  for (i = 0; i < in->nactions; i++)
    if (strcmp(in->actions[i].name, name) == 0) return i;
  return -1;
}

int sx_input_define_action(sx_input *in, const char *name, sx_action_kind kind) {
  int i = sx_input_find_action(in, name);
  sx_action *a;
  if (i >= 0) return in->actions[i].kind == kind ? i : -1;
  if (in->nactions >= SX_MAX_ACTIONS || strlen(name) >= sizeof in->actions[0].name) return -1;
  if (kind == SX_ACT_BUTTON && in->nbuttons >= SX_MAX_BUTTON_ACTIONS) return -1;
  if (kind == SX_ACT_AXIS && in->naxes >= SX_NUM_AXES) return -1;
  if (kind != SX_ACT_BUTTON && kind != SX_ACT_AXIS) return -1;
  a = &in->actions[in->nactions];
  strcpy(a->name, name);
  a->kind = kind;
  a->slot = kind == SX_ACT_BUTTON ? in->nbuttons++ : in->naxes++;
  return in->nactions++;
}

int sx_binding_parse(const char *s, sx_binding *out) {
  char buf[64], *dev, *name, *scale;
  int code = -1;
  if (!s || strlen(s) >= sizeof buf) return 0;
  strcpy(buf, s);
  dev = buf;
  name = strchr(buf, ':');
  if (!name) return 0;
  *name++ = 0;
  scale = strchr(name, ':');
  if (scale) *scale++ = 0;
  memset(out, 0, sizeof *out);
  out->scale = scale ? (float)atof(scale) : 1.0f;
  if (strcmp(dev, "key") == 0) {
    out->src = SX_SRC_KEY;
    code = sx_key_from_name(name);
  } else if (strcmp(dev, "mouse") == 0) {
    code = index_of(mouse_btns, name);
    if (code > 0) out->src = SX_SRC_MOUSE_BTN;
    else {
      out->src = SX_SRC_MOUSE_AXIS;
      code = index_of(mouse_axes, name);
    }
  } else if (strcmp(dev, "pad") == 0) {
    code = index_of(pad_buttons, name);
    if (code >= 0) out->src = SX_SRC_PAD_BTN;
    else {
      out->src = SX_SRC_PAD_AXIS;
      code = index_of(pad_axes, name);
    }
  } else if (strcmp(dev, "touch") == 0) {
    out->src = SX_SRC_TOUCH;
    code = sx_touch_ctl_from_name(name);
  } else if (strcmp(dev, "xr") == 0) {
    out->src = SX_SRC_XR;
    code = sx_xr_ctl_from_name(name);
  }
  if (code < 0) {
    out->src = SX_SRC_NONE;
    return 0;
  }
  out->code = code;
  return 1;
}

void sx_binding_format(const sx_binding *b, char *buf, int cap) {
  const char *dev = "?", *name = "?";
  switch (b->src) {
  case SX_SRC_KEY: dev = "key"; name = sx_key_name(b->code); break;
  case SX_SRC_MOUSE_BTN: dev = "mouse"; name = mouse_btns[b->code]; break;
  case SX_SRC_MOUSE_AXIS: dev = "mouse"; name = mouse_axes[b->code]; break;
  case SX_SRC_PAD_BTN: dev = "pad"; name = pad_buttons[b->code]; break;
  case SX_SRC_PAD_AXIS: dev = "pad"; name = pad_axes[b->code]; break;
  case SX_SRC_TOUCH: dev = "touch"; name = sx_touch_ctl_name(b->code); break;
  case SX_SRC_XR: dev = "xr"; name = sx_xr_ctl_name(b->code); break;
  default: break;
  }
  if (b->scale != 1.0f) snprintf(buf, (size_t)cap, "%s:%s:%g", dev, name, (double)b->scale);
  else snprintf(buf, (size_t)cap, "%s:%s", dev, name);
}

int sx_input_bind(sx_input *in, int player, int action, const char *binding) {
  sx_player_slot *p;
  sx_binding b;
  if (player < 1 || player > SX_MAX_PLAYERS || action < 0 || action >= in->nactions) return 0;
  if (!sx_binding_parse(binding, &b)) return 0;
  p = &in->players[player - 1];
  if (p->nbindings[action] >= SX_MAX_BINDINGS) return 0;
  p->bindings[action][p->nbindings[action]++] = b;
  return 1;
}

void sx_input_clear_bindings(sx_input *in, int player, int action) {
  if (player < 1 || player > SX_MAX_PLAYERS || action < 0 || action >= in->nactions) return;
  in->players[player - 1].nbindings[action] = 0;
}

int sx_input_owner(const sx_input *in, int device) {
  int p;
  if (device < 0 || device >= SX_NUM_DEVICES) return 0;
  for (p = 0; p < SX_MAX_PLAYERS; p++)
    if (in->players[p].claims[device]) return p + 1;
  return 0;
}

void sx_input_release(sx_input *in, int device) {
  int p;
  if (device < 0 || device >= SX_NUM_DEVICES) return;
  for (p = 0; p < SX_MAX_PLAYERS; p++) in->players[p].claims[device] = 0;
}

int sx_input_claim(sx_input *in, int player, int device) {
  if (player < 1 || player > SX_MAX_PLAYERS || device < 0 || device >= SX_NUM_DEVICES) return 0;
  sx_input_release(in, device);
  in->players[player - 1].claims[device] = 1;
  in->join_offer[device] = 0;
  if (!in->players[player - 1].active) {
    in->players[player - 1].active = 1;
    if (player > in->nplayers) in->nplayers = player;
  }
  return 1;
}

void sx_input_pad_connected(sx_input *in, int pad, int connected) {
  int dev = SX_DEV_PAD0 + pad, d, has_pad = 0;
  if (pad < 0 || pad >= SX_MAX_PADS) return;
  in->raw.pad_connected[pad] = connected;
  if (!connected) {
    sx_input_release(in, dev);
    in->join_offer[dev] = 0;
    memset(in->raw.pad_btn[pad], 0, sizeof in->raw.pad_btn[pad]);
    memset(in->raw.pad_axis[pad], 0, sizeof in->raw.pad_axis[pad]);
    return;
  }
  for (d = SX_DEV_PAD0; d < SX_NUM_DEVICES; d++)
    if (in->players[0].claims[d]) has_pad = 1;
  if (!has_pad && in->nplayers == 1) sx_input_claim(in, 1, dev);
  else if (!sx_input_owner(in, dev)) in->join_offer[dev] = 1; /* "Press A to join as P2" */
}

int16_t sx_quantize_axis(float v) {
  if (v != v) return 0;
  if (v >= 1.0f) return SX_AXIS_MAX;
  if (v <= -1.0f) return -SX_AXIS_MAX;
  return (int16_t)(v * (float)SX_AXIS_MAX + (v < 0 ? -0.5f : 0.5f));
}

static float dead(float v) { return (v > -0.15f && v < 0.15f) ? 0.0f : v; }

/* Value of one binding for the given player's claimed devices. */
static float binding_value(const sx_input *in, const sx_player_slot *p, const sx_binding *b, int axis, int *dev_used) {
  float v = 0, best = 0;
  int d;
  switch (b->src) {
  case SX_SRC_KEY:
    if (p->claims[SX_DEV_KBM] && b->code < 512 && in->raw.keys[b->code]) {
      *dev_used = SX_DEV_KBM;
      return axis ? b->scale : 1.0f;
    }
    return 0;
  case SX_SRC_MOUSE_BTN:
    if (p->claims[SX_DEV_KBM] && in->raw.mouse_btn[b->code]) {
      *dev_used = SX_DEV_KBM;
      return axis ? b->scale : 1.0f;
    }
    return 0;
  case SX_SRC_MOUSE_AXIS:
    if (!p->claims[SX_DEV_KBM]) return 0;
    v = in->raw.mouse_axis[b->code] * b->scale;
    if (v != 0) *dev_used = SX_DEV_KBM;
    return v;
  case SX_SRC_PAD_BTN:
  case SX_SRC_PAD_AXIS:
    for (d = 0; d < SX_MAX_PADS; d++) {
      if (!p->claims[SX_DEV_PAD0 + d] || !in->raw.pad_connected[d]) continue;
      if (b->src == SX_SRC_PAD_BTN) v = in->raw.pad_btn[d][b->code] ? (axis ? b->scale : 1.0f) : 0.0f;
      else v = dead(in->raw.pad_axis[d][b->code]) * b->scale;
      if (v != 0) *dev_used = SX_DEV_PAD0 + d;
      if ((v < 0 ? -v : v) > (best < 0 ? -best : best)) best = v;
    }
    return best;
  case SX_SRC_TOUCH:
    if (!p->claims[SX_DEV_TOUCH]) return 0;
    v = in->raw.touch[b->code] * b->scale;
    if (v != 0) *dev_used = SX_DEV_TOUCH;
    return v;
  case SX_SRC_XR:
    if (!p->claims[SX_DEV_XR]) return 0;
    v = in->raw.xr[b->code] * b->scale;
    if (v != 0) *dev_used = SX_DEV_XR;
    return v;
  default: return 0;
  }
}

void sx_input_build(sx_input *in, int64_t tick, sx_cmd *out, int *count) {
  int pi, a, k, n = 0, d;
  /* join offers: with co-op enabled, pressing A on an offered pad claims a slot */
  for (d = SX_DEV_PAD0; d < SX_NUM_DEVICES; d++) {
    if (in->join_offer[d] && in->coop_enabled && in->raw.pad_btn[d - SX_DEV_PAD0][0]) {
      for (pi = 0; pi < SX_MAX_PLAYERS; pi++) {
        if (!in->players[pi].active) {
          sx_input_claim(in, pi + 1, d);
          break;
        }
      }
    }
  }
  for (pi = 0; pi < SX_MAX_PLAYERS; pi++) {
    sx_player_slot *p = &in->players[pi];
    sx_cmd *c;
    float axes[SX_NUM_AXES] = {0};
    if (!p->active) continue;
    c = &out[n++];
    memset(c, 0, sizeof *c);
    c->player = pi + 1;
    c->tick = tick;
    for (a = 0; a < in->nactions; a++) {
      const sx_action *act = &in->actions[a];
      for (k = 0; k < p->nbindings[a]; k++) {
        int used = -1;
        float v = binding_value(in, p, &p->bindings[a][k], act->kind == SX_ACT_AXIS, &used);
        if (used >= 0) p->last_device = used;
        if (act->kind == SX_ACT_BUTTON) {
          if (v > 0.5f) c->buttons |= 1u << act->slot;
        } else {
          axes[act->slot] += v;
        }
      }
    }
    for (k = 0; k < SX_NUM_AXES; k++) c->axes[k] = sx_quantize_axis(axes[k]);
    if (p->claims[SX_DEV_XR]) memcpy(c->aim, in->raw.aim, sizeof c->aim);
    c->edges = c->buttons & ~p->prev_buttons;
    p->prev_buttons = c->buttons;
  }
  in->raw.mouse_axis[0] = in->raw.mouse_axis[1] = in->raw.mouse_axis[2] = 0;
  *count = n;
}

const char *sx_input_device_mode(const sx_input *in, int player) {
  int d;
  if (player < 1 || player > SX_MAX_PLAYERS) return "kbm";
  d = in->players[player - 1].last_device;
  if (d == SX_DEV_TOUCH) return "touch";
  if (d == SX_DEV_XR) return "xr";
  if (d >= SX_DEV_PAD0) return "pad";
  return "kbm";
}
