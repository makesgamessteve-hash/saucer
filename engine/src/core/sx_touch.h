/* Virtual touch controls for mobile web (floating left stick, look drag
 * anywhere else, vertical lift slider with UP/DN hold buttons, a 3x3 button
 * grid under the right thumb). Positions are normalized 0..1 of the game
 * image; add-mobile-touch-ux sizes everything in CSS px from the image size,
 * the safe-area insets and the HUD target, so the layout holds from a
 * 320x568 phone to a tablet, in portrait and landscape.
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
  SX_TOUCH_MAP,   /* add-wider-dark: sector map */
  SX_TOUCH_DECOY, /* add-wider-dark: throw a decoy */
  SX_TOUCH_GRAPPLE, /* add-playtest-recs: the on-foot grapple */
  SX_TOUCH_COUNT
} sx_touch_ctl;

enum {
  SX_TOUCH_KIND_BUTTON = 0,
  SX_TOUCH_KIND_STICK = 1,  /* the floating stick's zone (invisible; the ring is drawn) */
  SX_TOUCH_KIND_SLIDER = 2,
  SX_TOUCH_KIND_LOOK = 3,   /* everything no control claims */
  SX_TOUCH_KIND_HOLD = 4,   /* hold-to-climb/dive button */
  SX_TOUCH_KIND_TRAY = 5    /* declutter-touch-controls: opens and closes the tray */
};

/* declutter-touch-controls: which set a widget belongs to */
enum {
  SX_TOUCH_GROUP_CORE = 0, /* always shown: stick, lift, look, the tray button */
  SX_TOUCH_GROUP_GRID = 1, /* a fixed slot under the right thumb, shown in context (and not while the tray is open) */
  SX_TOUCH_GROUP_TRAY = 2  /* in the tray: shown while it is open */
};

typedef struct sx_touch_widget {
  const char *name;
  int ctl;          /* sx_touch_ctl it drives */
  float x, y, w, h; /* normalized rect */
  int kind;         /* SX_TOUCH_KIND_* */
  float sign;       /* kind 4: +1 up, -1 down */
  int group;        /* SX_TOUCH_GROUP_* */
} sx_touch_widget;

typedef struct sx_touch_rect {
  float x, y, w, h; /* normalized */
} sx_touch_rect;

/* add-mobile-touch-ux: what a layout is fitted to */
typedef struct sx_touch_metrics {
  float w, h;       /* the game image in CSS px */
  float safe[4];    /* safe-area insets over the image in CSS px: left, top, right, bottom */
  int hud_w, hud_h; /* the low-res target (HUD pixels) the image shows */
} sx_touch_metrics;

/* Design rules (CSS px): targets at least 48 (44 is the hard floor the tests
 * hold), gaps at least 8, everything scaled from min(w, h). */
#define SX_TOUCH_MIN_TARGET 44.0f
#define SX_TOUCH_MIN_GAP 8.0f
/* radial deadzone of the stick (fraction of its radius) */
#define SX_TOUCH_DEADZONE 0.12f
/* look drag gain: stick-units per CSS px of thumb travel (same on both axes) */
#define SX_TOUCH_LOOK_GAIN (1.0f / 60.0f)

#define SX_TOUCH_MAX_FINGERS 10
#define SX_TOUCH_MAX_WIDGETS 32
#define SX_TOUCH_MAX_HUD 3
typedef struct sx_touch {
  int active; /* becomes 1 on first touch event */
  int nwidgets;
  sx_touch_widget widgets[SX_TOUCH_MAX_WIDGETS];
  struct {
    long long id;
    int widget; /* -1 none */
    float sx, sy, x, y;
  } fingers[SX_TOUCH_MAX_FINGERS];
  int nfingers;
  float look_acc[2];
  float values[SX_TOUCH_COUNT];
  /* add-presentation-packaging: a press landing on a button/hold widget
   * bumps buzz (the web build turns it into a short vibration) */
  int buzz;
  /* add-mobile-touch-ux */
  sx_touch_metrics m;
  float unit, gap, margin; /* CSS px: button size, gap between targets, margin inside the safe area */
  float stick_r;           /* CSS px: the stick's throw */
  float slop[2];           /* normalized near-miss slop (half a gap) on x and y */
  int portrait;            /* 1: the lift column stands on the button grid */
  sx_touch_rect safe;      /* the safe area (normalized) */
  sx_touch_rect home;      /* the stick's resting ring (bounding box) */
  sx_touch_rect msg;       /* a column clear of controls for the message log and hints */
  float cx0, cx1;          /* the clear span for centred HUD text, mid-screen (normalized x) */
  sx_touch_rect hud[SX_TOUCH_MAX_HUD]; /* HUD keep-outs no control may cover */
  int nhud;
  /* declutter-touch-controls */
  int tray_open;
  sx_touch_rect tray;    /* the open tray's panel (normalized) */
  unsigned ctx_hide;     /* bit per sx_touch_ctl: its grid slot is out of context */
  unsigned shown;        /* bit per widget: drawn and hit-tested now */
  unsigned frame;        /* frames applied so far (for fades) */
  unsigned shown_frame[SX_TOUCH_MAX_WIDGETS]; /* the frame each widget last appeared */
} sx_touch;

/* Fingers that just miss a button still press it within the slop (half a
 * gap); kept for older callers, the layout sets t->slop. */
#define SX_TOUCH_SLOP 0.0125f

int sx_touch_ctl_from_name(const char *name);
const char *sx_touch_ctl_name(int ctl);
/* A layout for an image of this aspect whose short side is 360 CSS px
 * (headless runs and tests); the platform calls sx_touch_layout. */
void sx_touch_init(sx_touch *t, float aspect);
/* Fit the controls to m. Keeps `active`, lets go of every finger. */
void sx_touch_layout(sx_touch *t, const sx_touch_metrics *m);
/* The low-res target that fills a w x h CSS px window: the short side is
 * 200..270 HUD px (at least 1.33 CSS px each), the long side follows the
 * aspect up to 640; a big screen's long side is at least 480 (the full HUD). */
void sx_touch_fit_target(int w, int h, int *tw, int *th);
/* Do two normalized rects overlap (touching edges do not)? */
int sx_touch_overlap(const sx_touch_rect *a, const sx_touch_rect *b);
/* Widget i's rect (or the stick's resting ring) as a sx_touch_rect */
sx_touch_rect sx_touch_visible_rect(const sx_touch *t, int i);
void sx_touch_down(sx_touch *t, long long id, float x, float y);
void sx_touch_move(sx_touch *t, long long id, float x, float y);
void sx_touch_up(sx_touch *t, long long id);
/* Is any finger holding widget i? (for pressed highlights) */
int sx_touch_held(const sx_touch *t, int i);
/* The stick finger's base and current point -> 1 when the stick is held */
int sx_touch_stick(const sx_touch *t, float out[4]);
/* Write current values into raw->touch and reset look deltas; counts a frame
 * and settles the shown set. */
void sx_touch_apply(sx_touch *t, sx_raw_input *raw);
/* declutter-touch-controls: the actions (bit per sx_touch_ctl) whose grid
 * slots make sense now; the rest hide. Every action stays in the tray. */
void sx_touch_context(sx_touch *t, unsigned ctl_mask);
void sx_touch_set_tray(sx_touch *t, int open);
/* Is widget i shown (drawn, hit-tested)? */
int sx_touch_shown(const sx_touch *t, int i);
/* Should widget i be shown (context, tray)? */
int sx_touch_wanted(const sx_touch *t, int i);
/* Bring the shown set to the wanted one, except for a widget a finger holds
 * or rests on: it changes once that finger lifts or moves off (nothing
 * appears, vanishes or moves under a pressing finger). */
void sx_touch_settle(sx_touch *t);
#endif
