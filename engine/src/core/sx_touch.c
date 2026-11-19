/* SPDX-License-Identifier: MIT */
#include "sx_touch.h"
#include <math.h>
#include <string.h>

static const char *ctl_names[SX_TOUCH_COUNT] = {"stick_x", "stick_y", "look_x", "look_y", "lift",  "shrink",
                                                "grow",    "tractor", "scan",   "use",    "boost", "jam",
                                                "map",     "decoy",   "grapple"};

int sx_touch_ctl_from_name(const char *name) {
  int i;
  for (i = 0; i < SX_TOUCH_COUNT; i++)
    if (strcmp(ctl_names[i], name) == 0) return i;
  return -1;
}

const char *sx_touch_ctl_name(int ctl) { return (ctl >= 0 && ctl < SX_TOUCH_COUNT) ? ctl_names[ctl] : "?"; }

static float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
static float maxf(float a, float b) { return a > b ? a : b; }
static float minf(float a, float b) { return a < b ? a : b; }

/* a rect in CSS px while the layout is worked out */
typedef struct box {
  float x, y, w, h;
} box;

static box mk(float x, float y, float w, float h) {
  box b;
  b.x = x;
  b.y = y;
  b.w = w;
  b.h = h;
  return b;
}

static sx_touch_rect norm(const sx_touch *t, box b) {
  sx_touch_rect r;
  r.x = b.x / t->m.w;
  r.y = b.y / t->m.h;
  r.w = b.w / t->m.w;
  r.h = b.h / t->m.h;
  return r;
}

static void add(sx_touch *t, const char *name, int ctl, box b, int kind, float sign) {
  sx_touch_widget *wd = &t->widgets[t->nwidgets++];
  wd->group = SX_TOUCH_GROUP_CORE;
  sx_touch_rect r = norm(t, b);
  wd->name = name;
  wd->ctl = ctl;
  wd->x = r.x;
  wd->y = r.y;
  wd->w = r.w;
  wd->h = r.h;
  wd->kind = kind;
  wd->sign = sign;
}

void sx_touch_fit_target(int w, int h, int *tw, int *th) {
  int s, l, sh, lg;
  if (w < 1) w = 1;
  if (h < 1) h = 1;
  s = w < h ? w : h;
  l = w < h ? h : w;
  /* a HUD pixel is at least 1.33 CSS px (an 8 px label reads at 10.7 px or more);
   * big screens get a finer grid so a 4:3 tablet keeps the full HUD (400 wide) */
  sh = s * 3 / 4;
  sh = sh < 200 ? 200 : (sh > 270 ? 270 : sh);
  lg = (int)((float)sh * (float)l / (float)s + 0.5f);
  if (s >= 600 && lg < 480) {
    lg = 480;
    sh = (int)(480.0f * (float)s / (float)l + 0.5f);
  }
  lg = lg < sh ? sh : (lg > 640 ? 640 : lg);
  *tw = w >= h ? lg : sh;
  *th = w >= h ? sh : lg;
}

/* The button grid, three by three under the right thumb: index = row * 3 + col,
 * col 0 is the rightmost, row 0 the bottom (the thumb's resting arc). Each
 * action keeps its own fixed slot (declutter-touch-controls): Use and Boost
 * always show; the rest show only in context, so an empty slot stays empty
 * rather than the others sliding over. Folding is the far row; the scanner
 * and the map live in the tray only. */
static const struct {
  const char *name;
  int ctl;
} GRID[9] = {{"use", SX_TOUCH_USE},     {"tractor", SX_TOUCH_TRACTOR}, {"grapple", SX_TOUCH_GRAPPLE},
             {"boost", SX_TOUCH_BOOST}, {"jam", SX_TOUCH_JAM},         {"decoy", SX_TOUCH_DECOY},
             {NULL, -1},                {"grow", SX_TOUCH_GROW},       {"shrink", SX_TOUCH_SHRINK}};

/* the tray, rarest first: every action is reachable here */
#define TRAY_N 10
static const struct {
  const char *name;
  int ctl;
} TRAY[TRAY_N] = {{"map", SX_TOUCH_MAP},       {"scan", SX_TOUCH_SCAN},       {"jam", SX_TOUCH_JAM},
                  {"decoy", SX_TOUCH_DECOY},   {"grow", SX_TOUCH_GROW},       {"shrink", SX_TOUCH_SHRINK},
                  {"tractor", SX_TOUCH_TRACTOR}, {"grapple", SX_TOUCH_GRAPPLE}, {"use", SX_TOUCH_USE},
                  {"boost", SX_TOUCH_BOOST}};

/* Use and Boost (and the stick and lift) are core: never out of context */
#define CORE_CTLS ((1u << SX_TOUCH_USE) | (1u << SX_TOUCH_BOOST))

void sx_touch_layout(sx_touch *t, const sx_touch_metrics *m) {
  int active = t->active, tray_open = t->tray_open, i;
  unsigned ctx_hide = t->ctx_hide, frame = t->frame;
  float W, H, s, u, g, mg, p, px, L, R, B, top, gr, gt, gl, lh, sr, band, b0, b1;
  box lift, map, zone, home, msg;
  memset(t, 0, sizeof *t);
  t->active = active;
  t->tray_open = tray_open;
  t->ctx_hide = ctx_hide & ~CORE_CTLS;
  t->frame = frame;
  t->m = *m;
  t->m.w = W = m->w >= 1 ? m->w : 1;
  t->m.h = H = m->h >= 1 ? m->h : 1;
  if (t->m.hud_w < 1) t->m.hud_w = 1;
  if (t->m.hud_h < 1) t->m.hud_h = 1;
  for (i = 0; i < 4; i++)
    if (!(t->m.safe[i] > 0)) t->m.safe[i] = 0;
  s = minf(W, H);
  t->unit = u = clampf(0.14f * s, 48.0f, 72.0f);
  t->gap = g = maxf(SX_TOUCH_MIN_GAP, 0.18f * u);
  t->margin = mg = maxf(16.0f, 0.25f * u); /* clear of the edge-swipe gestures too */
  p = H / (float)t->m.hud_h;               /* CSS px per HUD px */
  px = W / (float)t->m.hud_w;
  L = t->m.safe[0] + mg;
  R = W - t->m.safe[2] - mg;
  B = H - t->m.safe[3] - mg;
  t->safe = norm(t, mk(t->m.safe[0], t->m.safe[1], W - t->m.safe[0] - t->m.safe[2], H - t->m.safe[1] - t->m.safe[3]));
  /* HUD keep-outs: the top rows (taller when the HUD is narrow and stacks its
   * navigation on the right), the status block, the crosshair */
  band = (t->m.hud_w < 400 ? 100.0f : 40.0f) * p;
  t->hud[0] = norm(t, mk(0, 0, W, band));
  t->hud[1] = norm(t, mk(0, 0, 200.0f * px, 64.0f * p));
  t->hud[2] = norm(t, mk(W * 0.5f - 16.0f * px, H * 0.5f - 16.0f * p, 32.0f * px, 32.0f * p));
  t->nhud = 3;
  top = maxf(t->m.safe[1] + mg, band + g);
  t->portrait = H > W;
  /* the lift column on the right edge: beside the grid in landscape (full
   * height), standing on it in portrait (the right thumb arcs up to it) */
  gr = t->portrait ? R : R - u - g;
  gt = B - 3.0f * u - 2.0f * g;
  gl = gr - 3.0f * u - 2.0f * g;
  if (t->portrait) {
    lh = minf(4.0f * u + 2.0f * g, gt - g - top);
    lift = mk(R - u, gt - g - lh, u, lh);
  } else lift = mk(R - u, top, u, B - top);
  add(t, "stick", SX_TOUCH_STICK_X, mk(0, 0, 0, 0), SX_TOUCH_KIND_STICK, 0); /* placed below */
  add(t, "lift", SX_TOUCH_LIFT, mk(lift.x, lift.y + u + g, u, lift.h - 2.0f * u - 2.0f * g), SX_TOUCH_KIND_SLIDER, 0);
  /* true 3D: hold UP / DN above and below the slider to climb or dive at full rate */
  add(t, "up", SX_TOUCH_LIFT, mk(lift.x, lift.y, u, u), SX_TOUCH_KIND_HOLD, 1.0f);
  add(t, "dn", SX_TOUCH_LIFT, mk(lift.x, lift.y + lift.h - u, u, u), SX_TOUCH_KIND_HOLD, -1.0f);
  for (i = 0; i < 9; i++) {
    int c = i % 3, r = i / 3;
    if (!GRID[i].name) continue;
    add(t, GRID[i].name, GRID[i].ctl, mk(gr - (float)(c + 1) * u - (float)c * g, B - (float)(r + 1) * u - (float)r * g, u, u),
        SX_TOUCH_KIND_BUTTON, 0);
    if (GRID[i].ctl != SX_TOUCH_USE && GRID[i].ctl != SX_TOUCH_BOOST) t->widgets[t->nwidgets - 1].group = SX_TOUCH_GROUP_GRID;
  }
  /* the tray button is a rare reach in the top corner of the right thumb's
   * area: left of the top of the lift column (where the map used to be) */
  map = mk(lift.x - g - u, lift.y, u, u);
  add(t, "more", -1, map, SX_TOUCH_KIND_TRAY, 0);
  /* floating stick: the thumb lands anywhere in the lower left, the ring
   * rests in the corner */
  zone = mk(t->m.safe[0], t->portrait ? maxf(top, H * 0.5f) : maxf(64.0f * p + g, H * 0.3f), 0, 0);
  zone.w = gl - g - zone.x;
  zone.h = H - t->m.safe[3] - zone.y;
  sr = minf(clampf(0.16f * s, 48.0f, 96.0f), minf((zone.x + zone.w - L) * 0.5f, (B - zone.y) * 0.5f));
  t->stick_r = sr;
  home = mk(L, B - 2.0f * sr, 2.0f * sr, 2.0f * sr);
  {
    sx_touch_rect z = norm(t, zone);
    t->widgets[0].x = z.x;
    t->widgets[0].y = z.y;
    t->widgets[0].w = z.w;
    t->widgets[0].h = z.h;
  }
  t->home = norm(t, home);
  /* the tray drops down from its button and fills leftward, clear of the
   * lift column, Use and Boost, and the stick's resting ring (it covers only
   * context slots, which hide while it is open); if that is too small it
   * may rise into the HUD's top band (it is a menu over the view while open) */
  {
    float x1 = gr - u - g, x0 = home.x + home.w + g, y0 = map.y + u + g, y1 = B, cu = u + g;
    int cols = (int)((x1 - x0 + g) / cu), rows = (int)((y1 - y0 + g) / cu), k;
    if (cols < 1) cols = 1;
    if (cols * rows < TRAY_N) { /* down from the safe top instead, beside the button */
      y0 = t->m.safe[1] + mg;
      x1 = map.x - g;
      cols = (int)((x1 - x0 + g) / cu);
      rows = (int)((y1 - y0 + g) / cu);
      if (cols < 1) cols = 1;
    }
    if (rows < 1) rows = 1;
    if (cols * rows > TRAY_N) cols = (TRAY_N + rows - 1) / rows;
    rows = (TRAY_N + cols - 1) / cols;
    for (k = 0; k < TRAY_N; k++) {
      int c = k % cols, r = k / cols;
      add(t, TRAY[k].name, TRAY[k].ctl, mk(x1 - (float)(c + 1) * u - (float)c * g, y0 + (float)r * cu, u, u),
          SX_TOUCH_KIND_BUTTON, 0);
      t->widgets[t->nwidgets - 1].group = SX_TOUCH_GROUP_TRAY;
    }
    t->tray = norm(t, mk(x1 - (float)cols * cu + g * 0.5f, y0 - g * 0.5f, (float)cols * cu, (float)rows * cu));
  }
  add(t, "look", SX_TOUCH_LOOK_X, mk(0, 0, W, H), SX_TOUCH_KIND_LOOK, 0); /* last: lowest priority */
  /* the clear column for the message log and hints: in landscape between the
   * stick ring and the grid when that holds 16 characters, else above the
   * ring left of the crosshair; in portrait above the controls */
  msg = mk(home.x + home.w + g, 0, gl - g - (home.x + home.w + g), 0);
  if (!t->portrait && msg.w >= 128.0f * px) {
    /* (under the "what Use does" line, which sits 40 HUD px below the crosshair) */
    msg.y = maxf(H * 0.5f + 52.0f * p + g, B - 70.0f * p);
    msg.h = B - msg.y;
  } else if (!t->portrait) {
    msg.x = L;
    msg.w = minf(gl, W * 0.5f - 16.0f * px) - g - L;
    msg.y = maxf(64.0f * p + g, home.y - g - 70.0f * p);
    msg.h = maxf(0, home.y - g - msg.y);
  } else {
    float y1 = minf(gt, home.y) - g;
    msg.x = L;
    msg.w = lift.x - g - L;
    msg.y = maxf(H * 0.5f + 16.0f * p + g, y1 - 70.0f * p);
    msg.h = maxf(0, y1 - msg.y);
    if (msg.y < map.y + map.h + g) msg.w = map.x - g - msg.x;
  }
  t->msg = norm(t, msg);
  /* the clear span mid-screen for centred text (alerts, prompts, the beam) */
  b0 = H * 0.5f - 64.0f * p;
  b1 = H * 0.5f + 72.0f * p;
  t->cx0 = (t->m.safe[0] + 4.0f) / W;
  t->cx1 = (W - t->m.safe[2] - 4.0f) / W;
  for (i = 0; i < t->nwidgets; i++) {
    sx_touch_rect r = sx_touch_visible_rect(t, i);
    if (t->widgets[i].kind == SX_TOUCH_KIND_LOOK || t->widgets[i].group == SX_TOUCH_GROUP_TRAY || r.y * H >= b1 ||
        (r.y + r.h) * H <= b0)
      continue;
    if (r.x + r.w * 0.5f > 0.5f) t->cx1 = minf(t->cx1, r.x - g / W);
    else t->cx0 = maxf(t->cx0, r.x + r.w + g / W);
  }
  t->slop[0] = g * 0.5f / W;
  t->slop[1] = g * 0.5f / H;
  /* no fingers yet: everything starts as wanted, long since faded in */
  for (i = 0; i < t->nwidgets; i++) {
    if (sx_touch_wanted(t, i)) t->shown |= 1u << i;
    t->shown_frame[i] = t->frame - 600u;
  }
}

int sx_touch_wanted(const sx_touch *t, int i) {
  const sx_touch_widget *w = &t->widgets[i];
  if (w->group == SX_TOUCH_GROUP_TRAY) return t->tray_open;
  if (w->group == SX_TOUCH_GROUP_GRID) return !t->tray_open && !(t->ctx_hide & (1u << w->ctl));
  return 1; /* core: the stick, the lift, Use, Boost, the tray button */
}

int sx_touch_shown(const sx_touch *t, int i) { return (t->shown >> i) & 1u; }

static int inside(const sx_touch_widget *w, float x, float y);
/* a finger holds widget i or rests on (or within the slop of) its rect */
static int busy(const sx_touch *t, int i) {
  const sx_touch_widget *w = &t->widgets[i];
  int f;
  if (w->kind == SX_TOUCH_KIND_LOOK) return 0;
  for (f = 0; f < t->nfingers; f++) {
    float x = t->fingers[f].x, y = t->fingers[f].y;
    if (t->fingers[f].widget == i) return 1;
    if (x >= w->x - t->slop[0] && x <= w->x + w->w + t->slop[0] && y >= w->y - t->slop[1] && y <= w->y + w->h + t->slop[1])
      return 1;
  }
  return 0;
}

void sx_touch_settle(sx_touch *t) {
  int i;
  for (i = 0; i < t->nwidgets; i++) {
    int want = sx_touch_wanted(t, i);
    if (want == sx_touch_shown(t, i) || busy(t, i)) continue;
    if (want) {
      t->shown |= 1u << i;
      t->shown_frame[i] = t->frame;
    } else t->shown &= ~(1u << i);
  }
}

void sx_touch_context(sx_touch *t, unsigned ctl_mask) {
  t->ctx_hide = ~ctl_mask & ~CORE_CTLS;
  sx_touch_settle(t);
}

void sx_touch_set_tray(sx_touch *t, int open) {
  t->tray_open = open ? 1 : 0;
  sx_touch_settle(t);
}

void sx_touch_init(sx_touch *t, float aspect) {
  sx_touch_metrics m;
  memset(&m, 0, sizeof m);
  if (aspect < 0.4f) aspect = 0.4f;
  t->tray_open = 0;
  t->ctx_hide = 0;
  t->frame = 0;
  m.w = aspect >= 1.0f ? 360.0f * aspect : 360.0f;
  m.h = aspect >= 1.0f ? 360.0f : 360.0f / aspect;
  sx_touch_fit_target((int)m.w, (int)m.h, &m.hud_w, &m.hud_h);
  t->active = 0;
  sx_touch_layout(t, &m);
}

int sx_touch_overlap(const sx_touch_rect *a, const sx_touch_rect *b) {
  const float e = 1e-5f;
  return a->x + e < b->x + b->w && b->x + e < a->x + a->w && a->y + e < b->y + b->h && b->y + e < a->y + a->h;
}

sx_touch_rect sx_touch_visible_rect(const sx_touch *t, int i) {
  sx_touch_rect r;
  const sx_touch_widget *w = &t->widgets[i];
  if (w->kind == SX_TOUCH_KIND_STICK) return t->home;
  r.x = w->x;
  r.y = w->y;
  r.w = w->w;
  r.h = w->h;
  return r;
}

static int inside(const sx_touch_widget *w, float x, float y) {
  return x >= w->x && x <= w->x + w->w && y >= w->y && y <= w->y + w->h;
}

/* how far outside widget w (normalized, in slops) a point is; 0 inside */
static float miss(const sx_touch *t, const sx_touch_widget *w, float x, float y) {
  float dx = maxf(0, maxf(w->x - x, x - (w->x + w->w))) / t->slop[0];
  float dy = maxf(0, maxf(w->y - y, y - (w->y + w->h))) / t->slop[1];
  return dx > dy ? dx : dy;
}

int sx_touch_held(const sx_touch *t, int i) {
  int f;
  for (f = 0; f < t->nfingers; f++)
    if (t->fingers[f].widget == i) return 1;
  return 0;
}

static int hit(const sx_touch *t, float x, float y) {
  int i, best = -1;
  float bd = 1.0f;
  /* the open tray lies over the rest (it may cover the stick's zone) */
  for (i = 0; i < t->nwidgets; i++)
    if (t->widgets[i].group == SX_TOUCH_GROUP_TRAY && sx_touch_shown(t, i) && inside(&t->widgets[i], x, y)) return i;
  for (i = 0; i < t->nwidgets; i++) {
    const sx_touch_widget *w = &t->widgets[i];
    if (w->kind == SX_TOUCH_KIND_LOOK || !sx_touch_shown(t, i) || !inside(w, x, y)) continue;
    /* one thumb per stick or slider: a second finger there looks around instead */
    if ((w->kind == SX_TOUCH_KIND_STICK || w->kind == SX_TOUCH_KIND_SLIDER) && sx_touch_held(t, i)) continue;
    return i;
  }
  /* forgiving pass: the nearest button within the slop (half a gap, so it is
   * never the neighbour's) still counts before the look area */
  for (i = 0; i < t->nwidgets; i++) {
    const sx_touch_widget *w = &t->widgets[i];
    float d;
    if ((w->kind != SX_TOUCH_KIND_BUTTON && w->kind != SX_TOUCH_KIND_HOLD && w->kind != SX_TOUCH_KIND_TRAY) ||
        !sx_touch_shown(t, i))
      continue;
    d = miss(t, w, x, y);
    if (d <= bd) {
      bd = d;
      best = i;
    }
  }
  if (best >= 0) return best;
  for (i = 0; i < t->nwidgets; i++)
    if (t->widgets[i].kind == SX_TOUCH_KIND_LOOK && inside(&t->widgets[i], x, y)) return i;
  return -1;
}

int sx_touch_stick(const sx_touch *t, float out[4]) {
  int f;
  for (f = 0; f < t->nfingers; f++) {
    int wi = t->fingers[f].widget;
    if (wi >= 0 && t->widgets[wi].kind == SX_TOUCH_KIND_STICK) {
      out[0] = t->fingers[f].sx;
      out[1] = t->fingers[f].sy;
      out[2] = t->fingers[f].x;
      out[3] = t->fingers[f].y;
      return 1;
    }
  }
  return 0;
}

static int find(const sx_touch *t, long long id) {
  int i;
  for (i = 0; i < t->nfingers; i++)
    if (t->fingers[i].id == id) return i;
  return -1;
}

static void update_finger(sx_touch *t, int f) {
  int wi = t->fingers[f].widget;
  const sx_touch_widget *w;
  if (wi < 0) return;
  w = &t->widgets[wi];
  if (w->kind == SX_TOUCH_KIND_STICK) {
    /* a round throw in CSS px (the same on both axes), a radial deadzone,
     * and a base that follows the thumb past the rim (no dead travel back) */
    float rx = t->stick_r / t->m.w, ry = t->stick_r / t->m.h;
    float dx = (t->fingers[f].x - t->fingers[f].sx) / rx, dy = (t->fingers[f].y - t->fingers[f].sy) / ry;
    float d = sqrtf(dx * dx + dy * dy), k;
    if (d > 1.0f) {
      dx /= d;
      dy /= d;
      t->fingers[f].sx = t->fingers[f].x - dx * rx;
      t->fingers[f].sy = t->fingers[f].y - dy * ry;
      d = 1.0f;
    }
    k = d <= SX_TOUCH_DEADZONE ? 0.0f : (d - SX_TOUCH_DEADZONE) / (1.0f - SX_TOUCH_DEADZONE) / d;
    t->values[SX_TOUCH_STICK_X] = dx * k;
    t->values[SX_TOUCH_STICK_Y] = dy * k;
  } else if (w->kind == SX_TOUCH_KIND_SLIDER) {
    t->values[SX_TOUCH_LIFT] = clampf(-((t->fingers[f].y - (w->y + w->h * 0.5f)) / (w->h * 0.5f)), -1, 1);
  } else if (w->kind == SX_TOUCH_KIND_BUTTON) {
    t->values[w->ctl] = 1.0f;
  } else if (w->kind == SX_TOUCH_KIND_HOLD) {
    t->values[SX_TOUCH_LIFT] = w->sign;
  }
}

void sx_touch_down(sx_touch *t, long long id, float x, float y) {
  int f, kind;
  t->active = 1;
  if (find(t, id) >= 0 || t->nfingers >= SX_TOUCH_MAX_FINGERS) return;
  f = t->nfingers++;
  t->fingers[f].id = id;
  t->fingers[f].widget = -1; /* not holding anything while the hit test looks */
  t->fingers[f].widget = hit(t, x, y);
  t->fingers[f].sx = t->fingers[f].x = x;
  t->fingers[f].sy = t->fingers[f].y = y;
  kind = t->fingers[f].widget >= 0 ? t->widgets[t->fingers[f].widget].kind : -1;
  if (kind == SX_TOUCH_KIND_BUTTON || kind == SX_TOUCH_KIND_HOLD || kind == SX_TOUCH_KIND_TRAY) t->buzz++;
  if (kind == SX_TOUCH_KIND_TRAY) t->tray_open = !t->tray_open;
  else if (kind == SX_TOUCH_KIND_LOOK && t->tray_open) {
    /* a tap beside the open tray closes it (and does not look around) */
    t->tray_open = 0;
    t->fingers[f].widget = -1;
  }
  update_finger(t, f);
  sx_touch_settle(t);
}

void sx_touch_move(sx_touch *t, long long id, float x, float y) {
  int f = find(t, id);
  if (f < 0) return;
  if (t->fingers[f].widget >= 0 && t->widgets[t->fingers[f].widget].kind == SX_TOUCH_KIND_LOOK) {
    t->look_acc[0] += (x - t->fingers[f].x) * t->m.w; /* CSS px of thumb travel */
    t->look_acc[1] += (y - t->fingers[f].y) * t->m.h;
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
    if (w->kind == SX_TOUCH_KIND_STICK) t->values[SX_TOUCH_STICK_X] = t->values[SX_TOUCH_STICK_Y] = 0;
    else if (w->kind == SX_TOUCH_KIND_SLIDER || w->kind == SX_TOUCH_KIND_HOLD)
      t->values[SX_TOUCH_LIFT] = 0; /* auto-hover: release = hold altitude */
    else if (w->kind == SX_TOUCH_KIND_BUTTON) t->values[w->ctl] = 0;
    if (w->group == SX_TOUCH_GROUP_TRAY) t->tray_open = 0; /* a pick closes the tray */
  }
  t->fingers[f] = t->fingers[--t->nfingers];
  sx_touch_settle(t);
}

void sx_touch_apply(sx_touch *t, sx_raw_input *raw) {
  int i;
  t->values[SX_TOUCH_LOOK_X] = clampf(t->look_acc[0] * SX_TOUCH_LOOK_GAIN, -1, 1);
  t->values[SX_TOUCH_LOOK_Y] = clampf(t->look_acc[1] * SX_TOUCH_LOOK_GAIN, -1, 1);
  t->look_acc[0] = t->look_acc[1] = 0;
  for (i = 0; i < SX_TOUCH_COUNT; i++) raw->touch[i] = t->values[i];
  t->frame++;
  sx_touch_settle(t);
}
